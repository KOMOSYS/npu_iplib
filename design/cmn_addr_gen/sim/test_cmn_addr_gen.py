import os
import sys
import torch
import random
import numpy as np
import pandas as pd
from math import ceil
from pathlib import Path
from tabulate import tabulate

import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.types import LogicArray
from cocotb.handle import SimHandleBase
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles, Combine

sys.path.append(str(Path(__file__).parent.parent.parent))
from base import *

class RandomConfig(BaseConfig):
    def __init__(self):
        self.depth = 5

    def randomize(self):
        self.addr_base   = 0

        self.addr_size = []
        self.addr_stride = []
        for i in range(self.depth):
            self.addr_size.append(10)
            self.addr_stride.append(1)


        self._ref_addr_list =[]
        for i in range(self.addr_size[4]):
            for j in range(self.addr_size[3]):
                for k in range(self.addr_size[2]):
                    for l in range(self.addr_size[1]):
                        for m in range(self.addr_size[0]):
                            ref_addr = m*self.addr_stride[0] + l*self.addr_stride[1] + k*self.addr_stride[2] + j*self.addr_stride[3] + i*self.addr_stride[4] + self.addr_base
                            self._ref_addr_list.append(ref_addr)


class CmnAddrGenTester(BaseTester):
    def __init__(self, dut, cfg):
        self._dut = dut
        self._cfg = cfg
        self._monit_port = Queue()
    
    def init_phase(self):
        self._dut.clk.value = 0
        self._dut.reset_n.value = 0
        self._dut.init_pulse.value = 0
        self._dut.addr_base.value = 0
        for i in range(self._cfg.depth):
            self._dut.addr_size[i].value = 0
            self._dut.addr_stride[i].value = 0
        self._dut.addr_req = 0

    async def reset_phase(self):
        self._dut.reset_n.value = 0
        await Timer(100, units="ns")
        self._dut.reset_n.value = 1

    async def main_phase(self):
        self.start_coroutine(self._driver())
        self.start_coroutine(self._monitor())
        self.start_coroutine(self._checker())
        await Combine(*self.coroutines)

        self.clear_coroutines()
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 1
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 0
        await ClockCycles(self._dut.clk, 10)
    
    def _set_register(self) -> None:
        self._dut.addr_base.value   = self._cfg.addr_base
        for i in range(self._cfg.depth):
            self._dut.addr_size[i].value   = self._cfg.addr_size[i]
            self._dut.addr_stride[i].value = self._cfg.addr_stride[i]

    async def _driver(self) -> None:
        self._set_register()
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 1
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 0

        await RisingEdge(self._dut.clk)
        for _ in range(len(self._cfg._ref_addr_list)):
            self._dut.addr_req.value = 1
            await RisingEdge(self._dut.clk)
        self._dut.addr_req.value = 0

    async def _monitor(self) -> None:
        for i in range(len(self._cfg._ref_addr_list)):
            while True:
                await RisingEdge(self._dut.clk)
                if self._dut.addr_valid.value: break
            addr = self._dut.addr.value.binstr
            self._monit_port.put_nowait(addr)

    async def _checker(self) -> None:
        for i in range(len(self._cfg._ref_addr_list)):
            addr = await self._monit_port.get()
            ref_addr = self._cfg._ref_addr_list[i]

            compare_datas = {
                "actual"   : str(int(addr, 2)),
                "expected" : str(ref_addr)
            }

            assert compare_datas["actual"] == compare_datas["expected"], \
                "\n" + tabulate(pd.DataFrame(compare_datas, index=["Value"]), headers="keys", tablefmt="pretty")

random_seed = int(os.getenv("RANDOM_SEED")) if os.getenv("RANDOM_SEED") is not None else 1
max_iter = int(os.getenv("MAX_ITER")) if os.getenv("MAX_ITER") is not None else 100

@cocotb.test()
@intr_handler
async def normal(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = CmnAddrGenTester(dut, cfg)

    tester.init_phase()
    await tester.reset_phase()

    for iter in range(1):
        cocotb.log.info(f"Iteration {iter}")
        set_seed(random_seed+iter)
        cfg.randomize()
        cocotb.log.info(cfg)

        with timeout(10, "m"):
            await tester.main_phase()
    clk.kill()