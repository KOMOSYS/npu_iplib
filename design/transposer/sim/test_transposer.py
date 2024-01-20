import os
import sys
import torch
import random
import itertools
import numpy as np
import pandas as pd
from math import ceil
from pathlib import Path
from tabulate import tabulate

import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.types import LogicArray
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Combine

import sequence
from base import *
from constant import *
from memory import *

class RandomConfig(BaseConfig):
    def randomize(self):
        self.dim = random.randint(2, 6)
        self.dtype = np.random.choice([np.int8, np.float32])
        self._dnum_in_word = 64 // np.dtype(self.dtype).itemsize

        while True:
            self.trp_info = list(range(self.dim))
            np.random.shuffle(self.trp_info)
            self.in_shape = tuple(np.random.randint(1, 193, size=self.dim))
            self.out_shape = tuple([self.in_shape[i] for i in self.trp_info])
            if max(self._get_mem_depth(self.in_shape), self._get_mem_depth(self.out_shape)) < (1<<16):
                break
        
        if self.dtype == np.int8:
            in_data = np.random.randint(INT8MIN, INT8MAX+1, size=self.in_shape, dtype=np.int8)
        elif self.dtype == np.float32:
            in_data = np.random.rand(*self.in_shape).astype(np.float32)
        ref_data = in_data.transpose(*self.trp_info)

        self.raddr_base = random.randint(0, (1<<16) - self._get_mem_depth(self.in_shape))
        self.waddr_base = random.randint(0, (1<<16) - self._get_mem_depth(self.out_shape))

        self.packed_dim = self.trp_info[-1]
        self.packed_dim_rd_size = self.in_shape[self.packed_dim]
        self.packed_dim_rd_stride = self._get_addr_info(self.in_shape, self.packed_dim)["stride"]
        self.unpacked_dim = max(self.trp_info)
        self.unpacked_dim_wr_size = self.in_shape[self.unpacked_dim]
        self.unpacked_dim_wr_stride = self._get_addr_info(self.out_shape, self.trp_info.index(self.unpacked_dim))["stride"]
        self.repack_en = self.packed_dim != self.unpacked_dim

        self.rd_addr_info = []
        self.wr_addr_info = []
        for i in range(self.dim):
            if (i != self.unpacked_dim and i != self.packed_dim) or (not self.repack_en):
                self.rd_addr_info.append(self._get_addr_info(in_data.shape, i))
                self.wr_addr_info.append(self._get_addr_info(ref_data.shape, self.trp_info.index(i)))
        self.rd_addr_info = self.rd_addr_info[::-1]
        self.wr_addr_info = self.wr_addr_info[::-1]
        self.areq_num = int(np.prod([i["size"] for i in self.rd_addr_info]))

        self._input_mem = Memory(in_data, append_last=False)
        self._output_mem = Memory(ref_data, append_last=False)
    
    def _get_mem_depth(self, shape):
        return np.prod(shape[:-1]) * ceil(shape[-1] / self._dnum_in_word)
    
    def _get_addr_info(self, shape, idx):
        if idx == len(shape) - 1:
            return {"size": ceil(shape[idx] / self._dnum_in_word), "stride": 1}
        else:
            return {"size": shape[idx], "stride": int(np.prod(shape[idx+1:-1]) * ceil(shape[-1] / self._dnum_in_word))}


class TransposerTester(BaseTester):
    def __init__(self, dut, cfg):
        self._dut = dut
        self._cfg = cfg
        self._mem_rd_delay = 8
        self._mon_port = Queue()
    
    def init_phase(self):
        self._dut.reset_n.value = 0
        self._dut.init_pulse.value = 0
        self._dut.repack_en.value = 0
        self._dut.mode.value = 0

        self._dut.raddr_base.value = 0
        self._dut.waddr_base.value = 0
        self._dut.raddr_size.value = [0] * self._dut.ADIM.value
        self._dut.raddr_stride.value = [0] * self._dut.ADIM.value
        self._dut.waddr_size.value = [0] * self._dut.ADIM.value
        self._dut.waddr_stride.value = [0] * self._dut.ADIM.value

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
        await Combine(*self.coroutines, FallingEdge(self._dut.finish))
        self.clear_coroutines()
    
    def _set_register(self) -> None:
        self._dut.repack_en.value = 1 if self._cfg.repack_en else 0
        self._dut.mode.value = 1 if self._cfg.dtype == np.int8 else 2
        self._dut.raddr_base.value = self._cfg.raddr_base
        self._dut.waddr_base.value = self._cfg.waddr_base
        for i in range(self._dut.ADIM.value):
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

    async def _driver(self) -> None:
        self._set_register()
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 1
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 0
        self.start_coroutine(self._mem_read())

    async def _monitor(self) -> None:
        for _ in range(self._cfg._output_mem.depth):
            await RisingEdge(self._dut.clk)
            while not self._dut.wdata_vld.value:
                await RisingEdge(self._dut.clk)
            addr = self._dut.waddr.value.integer - self._cfg.waddr_base
            data = self._dut.wdata.value.binstr
            self._mon_port.put_nowait((addr, data))

    async def _checker(self) -> None:
        for _ in range(self._cfg._output_mem.depth):
            addr, data = await self._mon_port.get()
            mask = self._cfg._output_mem.get_mask(addr)
            actual = hex(np.bitwise_and(int(data, 2), int(mask, 2)))
            expected = hex(np.bitwise_and(int(self._cfg._output_mem[addr], 2), int(mask, 2)))
            if actual != expected:
                self._cfg._input_mem.dump("input.hex")
                self._cfg._output_mem.dump("ref.hex")
                compare_datas = {
                    "actual": {"addr": addr, "data": actual},
                    "expected": {"addr": addr, "data": expected}
                }
                assert 0, "\n" + tabulate(pd.DataFrame(compare_datas), headers="keys", tablefmt="pretty")

    async def _mem_read(self):
        rdfifo = []
        for _ in range(self._cfg._input_mem.depth):
            while True:
                await RisingEdge(self._dut.clk)
                if self._dut.raddr_vld.value:
                    raddr = self._dut.raddr.value.integer - self._cfg.raddr_base
                    rdfifo.append({"addr": raddr, "delay":self._mem_rd_delay})
                for i in rdfifo:
                    i["delay"] -= 1
                if rdfifo and rdfifo[0]["delay"] == 0:
                    self._dut.rdata.value = LogicArray(self._cfg._input_mem[rdfifo[0]["addr"]])
                    self._dut.rdata_vld.value = 1
                    rdfifo.pop(0)
                else:
                    self._dut.rdata_vld.value = 0
        self._dut.rdata_vld.value = 0

                
random_seed = int(os.getenv("RANDOM_SEED")) if os.getenv("RANDOM_SEED") is not None else 1
max_iter = int(os.getenv("MAX_ITER")) if os.getenv("MAX_ITER") is not None else 100

@cocotb.test()
@intr_handler
async def small_img(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = TransposerTester(dut, cfg)
    tester.init_phase()
    await tester.reset_phase()

    for iter in range(max_iter):
        cocotb.log.info(f"Iteration {iter}")
        set_seed(random_seed+iter)
        cfg.unfreeze("dim", "in_shape")
        cfg.dim = random.randint(2, 6)
        cfg.in_shape = [1] * cfg.dim
        cfg.in_shape[-1] = np.random.randint(2, 193)
        np.random.shuffle(cfg.in_shape)
        cfg.in_shape = tuple(cfg.in_shape)
        cfg.freeze("dim", "in_shape")
        cfg.randomize()
        cocotb.log.info(cfg)

        with timeout(10, "m"):
            await tester.main_phase()
    clk.kill()

@cocotb.test()
@intr_handler
async def random_dynamic_reset(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = TransposerTester(dut, cfg)
    tester.init_phase()
    await tester.reset_phase()

    for iter in range(max_iter):
        cocotb.log.info(f"Iteration {iter}")
        set_seed(random_seed+iter)
        cfg.randomize()
        cocotb.log.info(cfg)
        with timeout(10, "m"):
            await sequence.dynamic_reset(tester, cfg)
    clk.kill()

@cocotb.test()
@intr_handler
async def directed_dynamic_reset(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = TransposerTester(dut, cfg)
    tester.init_phase()
    await tester.reset_phase()

    set_seed(random_seed)
    cfg.randomize()

    async def chk_sig_eq(signal, value):
        while signal.value != value:
            await RisingEdge(dut.clk)

    for i in range(5):
        cfg.dync_rst_trg = f"rcsm[{i}]"
        cocotb.log.info(cfg)
        with timeout(10, "m"):
            condition = cocotb.start_soon(chk_sig_eq(getattr(dut, "u_transposer.rcsm"), 1<<i))
            await sequence.dynamic_reset(tester, cfg, condition)

    for i in range(5):
        cfg.dync_rst_trg = f"wcsm[{i}]"
        cocotb.log.info(cfg)
        with timeout(10, "m"):
            condition = cocotb.start_soon(chk_sig_eq(getattr(dut, "u_transposer.wcsm"), 1<<i))
            await sequence.dynamic_reset(tester, cfg, condition)

    clk.kill()

@cocotb.test()
@intr_handler
async def normal(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = TransposerTester(dut, cfg)
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