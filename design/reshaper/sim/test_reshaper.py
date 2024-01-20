import os
import random
import itertools
import numpy as np
import pandas as pd
from math import ceil
from tabulate import tabulate

import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.types import LogicArray
from cocotb.triggers import Timer, RisingEdge, Combine

from base import *
from constant import *
from memory import *

class RandomConfig(BaseConfig):
    def randomize(self):
        input_dim = random.randint(2, 6)
        self.dsize = np.random.choice([1, 4])
        self._dnum_in_word = 64 // self.dsize

        while True:
            self.in_shape = tuple(np.random.randint(1, 193, size=input_dim))
            if self._get_mem_depth(self.in_shape) >= (1<<16):
                continue
            self.out_shape = list(self.in_shape)
            np.random.shuffle(self.out_shape)
            if self._get_mem_depth(self.out_shape) >= (1<<16):
                continue
            if self.in_shape[-1] != self.out_shape[-1]:
                break

        if self.dsize == 1:
            in_data = np.random.randint(INT8MIN, INT8MAX, size=self.in_shape).astype(np.int8)
        else:
            in_data = np.random.rand(*self.in_shape).astype(np.float32)
        ref_data = in_data.reshape(*self.out_shape)

        self.raddr_base = random.randint(0, (1<<16) - self._get_mem_depth(self.in_shape))
        self.waddr_base = random.randint(0, (1<<16) - self._get_mem_depth(self.out_shape))

        self.rd_addr_info = [self._get_addr_info(in_data.shape, i) for i in range(in_data.ndim)][::-1]
        self.wr_addr_info = [self._get_addr_info(ref_data.shape, i) for i in range(ref_data.ndim)][::-1]

        self.rdata_size = in_data.shape[-1] * self.dsize
        self.wdata_size = ref_data.shape[-1] * self.dsize
        self._input_mem = Memory(in_data, append_last=False)
        self._output_mem = Memory(ref_data, append_last=False)
    
    def _get_mem_depth(self, shape):
        return np.prod(shape[:-1]) * ceil(shape[-1] / self._dnum_in_word)
    
    def _get_addr_info(self, shape, idx):
        if idx == len(shape) - 1:
            return {"size": ceil(shape[idx] / self._dnum_in_word), "stride": 1}
        else:
            return {"size": shape[idx], "stride": int(np.prod(shape[idx+1:-1]) * ceil(shape[-1] / self._dnum_in_word))}


class ReshaperTester(BaseTester):
    def __init__(self, dut, cfg):
        self._dut = dut
        self._cfg = cfg
        self._mem_rd_delay = self._dut.MEM_DELAY.value
        self._mon_port = Queue()
    
    def init_phase(self):
        self._dut.reset_n.value = 0
        self._dut.init_pulse.value = 0

        self._dut.rreq_num.value = 0
        self._dut.wreq_num.value = 0
        self._dut.raddr_base.value = 0
        self._dut.waddr_base.value = 0
        self._dut.raddr_size.value = [0] * self._dut.ADIM.value
        self._dut.raddr_stride.value = [0] * self._dut.ADIM.value
        self._dut.waddr_size.value = [0] * self._dut.ADIM.value
        self._dut.waddr_stride.value = [0] * self._dut.ADIM.value

        self._dut.rdata_size.value = 0
        self._dut.wdata_size.value = 0

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
    
    def _set_register(self) -> None:
        self._dut.rreq_num.value = self._cfg._input_mem.depth
        self._dut.wreq_num.value = self._cfg._output_mem.depth
        self._dut.raddr_base.value = self._cfg.raddr_base
        self._dut.waddr_base.value = self._cfg.waddr_base
        for i in range(self._dut.ADIM.value):
            if i < len(self._cfg.rd_addr_info):
                self._dut.raddr_size[i].value = int(self._cfg.rd_addr_info[i]["size"])
                self._dut.raddr_stride[i].value = int(self._cfg.rd_addr_info[i]["stride"])
            if i < len(self._cfg.wr_addr_info):
                self._dut.waddr_size[i].value = int(self._cfg.wr_addr_info[i]["size"])
                self._dut.waddr_stride[i].value = int(self._cfg.wr_addr_info[i]["stride"])
        self._dut.rdata_size.value = int(self._cfg.rdata_size)
        self._dut.wdata_size.value = int(self._cfg.wdata_size)

    async def _driver(self) -> None:
        self._set_register()
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 1
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 0
        self.start_coroutine(self._mem_read())

    async def _monitor(self) -> None:
        for addr in range(self._cfg._output_mem.depth):
            await RisingEdge(self._dut.clk)
            while not self._dut.wdata_vld.value:
                await RisingEdge(self._dut.clk)
            self._mon_port.put_nowait(self._dut.wdata.value.binstr)

    async def _checker(self) -> None:
        for addr, ref_data in enumerate(self._cfg._output_mem):
            data = await self._mon_port.get()
            vld_byte = self._cfg._output_mem.get_vld_byte(addr)

            compare_datas = {
                "actual": {"addr": addr, "data": hex(int(data[-vld_byte*8:], 2))},
                "expected": {"addr": addr, "data": hex(int(ref_data[-vld_byte*8:], 2))}
            }
            if compare_datas["actual"] != compare_datas["expected"]:
                self._cfg._input_mem.dump("input.hex")
                self._cfg._output_mem.dump("ref.hex")
                assert 0, "\n" + tabulate(pd.DataFrame(compare_datas), headers="keys", tablefmt="pretty")
    
    async def _mem_read(self):
        rdfifo = []
        for _ in range(self._cfg._input_mem.depth):
            while True:
                await RisingEdge(self._dut.clk)
                if self._dut.raddr_vld.value:
                    raddr = self._dut.raddr.value - self._cfg.raddr_base
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
async def normal(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = ReshaperTester(dut, cfg)

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