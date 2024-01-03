import os
import sys
import torch
import random
import itertools
import numpy as np
import pandas as pd
from math import ceil
from pathlib import Path
from functools import reduce
from tabulate import tabulate

import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.types import LogicArray
from cocotb.handle import SimHandleBase
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles, Combine

from base import *
from constant import *
from formatter import *

class RandomConfig(BaseConfig):
    def randomize(self):
        self.dim = random.randint(2, 6)
        while True:
            self.mode = np.random.choice(["BIT8_MODE", "BIT32_MODE"])
            if self.mode == "BIT8_MODE":
                self._dnum_in_word = 64
            elif self.mode == "BIT32_MODE":
                self._dnum_in_word = 16

            self.trp_info = list(range(self.dim))
            np.random.shuffle(self.trp_info)
            self.in_shape = tuple(np.random.randint(1, 193, size=self.dim))
            self.ref_shape = tuple([self.in_shape[i] for i in self.trp_info])
            
            if self._get_mem_depth(self.in_shape) < (1<<16) and self._get_mem_depth(self.ref_shape) < (1<<16):
                break
        
        self.raddr_base = random.randint(0, (1<<16) - self._get_mem_depth(self.in_shape))
        self.waddr_base = random.randint(0, (1<<16) - self._get_mem_depth(self.ref_shape))

        if self.mode == "BIT8_MODE":
            in_data = np.random.randint(INT8MIN, INT8MAX, size=self.in_shape).astype(np.int8)
        elif self.mode == "BIT32_MODE":
            in_data = np.random.rand(*self.in_shape).astype(np.float32)
        ref_data = in_data.transpose(*self.trp_info)
        self._input_mem = np2mem(self._split2word(in_data))
        self._output_mem = np2mem(self._split2word(ref_data))
        
        self.packed_dim = self.trp_info[-1]
        self.packed_dim_rd_size = self.in_shape[self.packed_dim]
        self.packed_dim_rd_stride = self._get_addr_stride(self.in_shape, self.packed_dim)
        self.unpacked_dim = max(self.trp_info)
        self.unpacked_dim_wr_size = self.in_shape[self.unpacked_dim]
        self.unpacked_dim_wr_stride = self._get_addr_stride(self.ref_shape, self.trp_info.index(self.unpacked_dim))
        self.repack_en = self.packed_dim != self.unpacked_dim

        self.rd_addr_info = []
        self.wr_addr_info = []
        for i in range(self.dim):
            if (i != self.unpacked_dim and i != self.packed_dim) or (not self.repack_en):
                self.rd_addr_info.append({"dim": i,
                                          "size": self._get_addr_size(in_data.shape, i),
                                          "stride": self._get_addr_stride(in_data.shape, i)})
                self.wr_addr_info.append({"dim": i,
                                          "size": self._get_addr_size(ref_data.shape, self.trp_info.index(i)),
                                          "stride": self._get_addr_stride(ref_data.shape, self.trp_info.index(i))})
        self.areq_num = reduce(lambda x, y: x*y, [i["size"] for i in self.rd_addr_info], 1)

        self._rd_addr_list = self._addr_gen(self.rd_addr_info)
        self._wr_addr_list = self._addr_gen(self.wr_addr_info)
        self.rd_addr_info = self.rd_addr_info[::-1]
        self.wr_addr_info = self.wr_addr_info[::-1]
    
    def _get_mem_depth(self, shape):
        return reduce(lambda x, y: x*y, shape[:-1]) * ceil(shape[-1] / self._dnum_in_word)
    
    def _split2word(self, data):
        shape = data.shape
        data = fill_zero(data, list(shape)[:-1] + [ceil(shape[-1] / self._dnum_in_word) * self._dnum_in_word])
        return data.reshape(-1, self._dnum_in_word)
    
    def _get_addr_size(self, shape, idx):
        if idx == len(shape) - 1:
            return ceil(shape[idx] / self._dnum_in_word)
        else:
            return shape[idx]

    def _get_addr_stride(self, shape, idx):
        if idx == len(shape) - 1:
            return 1
        elif self.mode == "BIT8_MODE":
            return reduce(lambda x, y: x*y, shape[idx+1:-1], ceil(shape[-1] / 64))
        elif self.mode == "BIT32_MODE":
            return reduce(lambda x, y: x*y, shape[idx+1:-1], ceil(shape[-1] / 16))

    def _addr_gen(self, addr_info):
        addr_list = []
        addr_info = [info for info in addr_info if info["size"] != 1]
        for indices in itertools.product(*[range(info["size"]) for info in addr_info]):
            stride = [i["stride"] for i in addr_info]
            addr_list.append(sum([i*j for i, j in zip(indices, stride)]))
        return addr_list


class TransposeTester(BaseTester):
    def __init__(self, dut, cfg):
        self._dut = dut
        self._cfg = cfg
        self._mem_rd_delay = 7
        self._mon_port = Queue()
    
    def init_phase(self):
        self._dut.clk.value = 0
        self._dut.reset_n.value = 0
        self._dut.init_pulse.value = 0
        self._dut.repack_en.value = 0
        self._dut.mode.value = 0

        self._dut.raddr_base.value = 0
        self._dut.waddr_base.value = 0
        self._dut.raddr_size.value = [0] * self._dut.ADIMD.value
        self._dut.raddr_stride.value = [0] * self._dut.ADIMD.value
        self._dut.waddr_size.value = [0] * self._dut.ADIMD.value
        self._dut.waddr_stride.value = [0] * self._dut.ADIMD.value

        self._dut.areq_num.value = 0
        
        self._dut.packed_dim_rsize.value = 0
        self._dut.packed_dim_rstride.value = 0
        self._dut.unpacked_dim_wsize.value = 0
        self._dut.unpacked_dim_wstride.value = 0

        self._dut.rdata.value = 0
        self._dut.rdata_vld.value = 0

    async def reset_phase(self):
        self._dut.reset_n.value = 0
        await Timer(100, units="ns")
        self._dut.reset_n.value = 1

    async def main_phase(self):
        self.start_coroutine(self._driver())
        self.start_coroutine(self._monitor())
        self.start_coroutine(self._checker())
        await Combine(*self.coroutines, RisingEdge(self._dut.finish))

        self.clear_coroutines()

    async def _driver(self) -> None:
        self._set_register()

        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 1
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 0

        self.start_coroutine(self._mem_read())

    async def _monitor(self) -> None:
        for _ in range(len(self._cfg._output_mem)):
            await RisingEdge(self._dut.clk)
            while not self._dut.wdata_vld.value:
                await RisingEdge(self._dut.clk)
            addr = self._dut.waddr.value.integer - self._cfg.waddr_base
            data = self._dut.wdata.value.binstr
            self._mon_port.put_nowait((addr, data))

    async def _checker(self) -> None:
        waddr_list = []
        for iter in range(len(self._cfg._output_mem)):
            addr, data = await self._mon_port.get()
            waddr_list.append(addr)
            vld_byte = self._get_vld_byte(self._cfg.ref_shape, addr)
            actual = data[-vld_byte * 8:]
            expected = self._cfg._output_mem[addr][-vld_byte * 8:]
            compare_datas = {
                "actual": {"addr": addr, "data": hex(int(actual, 2))},
                "expected": {"addr": addr, "data": hex(int(expected, 2))}
            }
            assert compare_datas["actual"] == compare_datas["expected"], "\n" + tabulate(
                pd.DataFrame(compare_datas), headers="keys", tablefmt="pretty")
        assert len(set(waddr_list)) == len(waddr_list), "Duplicated Write Address"

    def _set_register(self) -> None:
        self._dut.repack_en.value = 1 if self._cfg.repack_en else 0
        self._dut.mode.value = 1 if self._cfg.mode == "BIT8_MODE" else 2
        self._dut.raddr_base.value = self._cfg.raddr_base
        self._dut.waddr_base.value = self._cfg.waddr_base
        for i in range(self._dut.ADIMD.value):
            if i < len(self._cfg.rd_addr_info):
                self._dut.raddr_size[i].value = int(self._cfg.rd_addr_info[i]["size"])
                self._dut.raddr_stride[i].value = int(self._cfg.rd_addr_info[i]["stride"])
            if i < len(self._cfg.wr_addr_info):
                self._dut.waddr_size[i].value = int(self._cfg.wr_addr_info[i]["size"])
                self._dut.waddr_stride[i].value = int(self._cfg.wr_addr_info[i]["stride"])
        self._dut.areq_num.value = int(self._cfg.areq_num)
        self._dut.packed_dim_rsize.value = int(self._cfg.packed_dim_rd_size) if self._cfg.repack_en else 0
        self._dut.packed_dim_rstride.value = int(self._cfg.packed_dim_rd_stride) if self._cfg.repack_en else 0
        self._dut.unpacked_dim_wsize.value = int(self._cfg.unpacked_dim_wr_size) if self._cfg.repack_en else 0
        self._dut.unpacked_dim_wstride.value = int(self._cfg.unpacked_dim_wr_stride) if self._cfg.repack_en else 0

    async def _mem_read(self):
        rdfifo = []
        for _ in range(len(self._cfg._input_mem)):
            while True:
                await RisingEdge(self._dut.clk)
                for i in rdfifo:
                    i["delay"] -= 1
                if self._dut.raddr_vld.value:
                    raddr = self._dut.raddr.value - self._cfg.raddr_base
                    rdfifo.append({"addr": raddr, "delay":self._mem_rd_delay})
                if rdfifo and rdfifo[0]["delay"] == 0:
                    self._dut.rdata.value = LogicArray(self._cfg._input_mem[rdfifo[0]["addr"]].zfill(512))
                    self._dut.rdata_vld.value = 1
                    rdfifo.pop(0)
                else:
                    self._dut.rdata_vld.value = 0
        self._dut.rdata_vld.value = 0
    
    def _get_vld_byte(self, shape, addr):
        if shape[-1] < 64 and self._cfg.mode == "BIT8_MODE":
            return shape[-1]
        elif shape[-1] < 16 and self._cfg.mode == "BIT32_MODE":
            return shape[-1] * 4
        elif self._cfg.mode == "BIT8_MODE":
            data_wsize = ceil(shape[-1] / 64)
            return shape[-1] % 64 if addr % data_wsize == data_wsize - 1 else 64
        elif self._cfg.mode == "BIT32_MODE":
            data_wsize = ceil(shape[-1] / 16)
            return (shape[-1] % 16) * 4 if addr % data_wsize == data_wsize - 1 else 64

                
random_seed = int(os.getenv("RANDOM_SEED")) if os.getenv("RANDOM_SEED") is not None else 1
max_iter = int(os.getenv("MAX_ITER")) if os.getenv("MAX_ITER") is not None else 100

@cocotb.test()
@intr_handler
async def normal(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = TransposeTester(dut, cfg)

    tester.init_phase()
    await tester.reset_phase()

    for iter in range(max_iter):
        cocotb.log.info(f"Iteration {iter}")
        set_seed(random_seed+iter)
        cfg.randomize()
        cocotb.log.info(cfg)

        with timeout(10, "m"):
            await tester.main_phase()
    clk.kill()