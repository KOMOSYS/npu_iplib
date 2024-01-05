import os
import random
import itertools
import numpy as np
import pandas as pd
from tabulate import tabulate

import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.triggers import Timer, RisingEdge, ClockCycles, Combine

from base import *

class RandomConfig(BaseConfig):
    def randomize(self):
        while True:
            addr_width = 8
            depth = 5

            use_depth = random.randint(1, 5)
            self.base_addr = random.randrange(0, 1<<addr_width)
            self.size = [random.randrange(1, addr_width) if i < use_depth else 0 for i in range(depth)]
            self.stride = [random.randrange(1, addr_width) if i < use_depth else 0 for i in range(depth)]

            cnt_list = [list(range(0, self.size[i]*self.stride[i], self.stride[i])) if i < use_depth else 0 for i in range(use_depth)]
            if use_depth > 1: 
                for i in range(1, use_depth): cnt_list[i] = [x + y for x,y in list(itertools.product(cnt_list[i], cnt_list[i-1]))]
            self._ref_addr = np.array(cnt_list[use_depth - 1]) + self.base_addr
            if (self.base_addr + np.array(self._ref_addr).max()) < (1<<addr_width): break

class NestedAddrGenTester(BaseTester):
    def __init__(self, dut, cfg):
        self._dut = dut
        self._cfg = cfg
        self._monit_port = Queue()
    
    def init_phase(self):
        self._dut.clk.value = 0
        self._dut.reset_n.value = 0
        self._dut.init_pulse.value = 0
        self._dut.base.value = 0
        for i in range(self._dut.DEPTH.value):
            self._dut.size[i].value = 0
            self._dut.stride[i].value = 0
        self._dut.addr_req.value = 0

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
        await ClockCycles(self._dut.clk, 10)
    
    def _set_register(self) -> None:
        self._dut.base.value = self._cfg.base_addr
        for i in range(self._dut.DEPTH.value):
            self._dut.size[i].value = self._cfg.size[i]
            self._dut.stride[i].value = self._cfg.stride[i]

    async def _driver(self) -> None:
        self._set_register()
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 1
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 0
        await RisingEdge(self._dut.clk)

        for _ in range(len(self._cfg._ref_addr)):
            self._dut.addr_req.value = 1
            await RisingEdge(self._dut.clk)
        self._dut.addr_req.value = 0
        await RisingEdge(self._dut.clk)

    async def _monitor(self) -> None:
        for i in range(len(self._cfg._ref_addr)):
            await RisingEdge(self._dut.clk)
            while not self._dut.addr_vld.value:
                await RisingEdge(self._dut.clk)
            
            addr = self._dut.addr.value.binstr
            self._monit_port.put_nowait(addr)

    async def _checker(self) -> None:
        for i in range(len(self._cfg._ref_addr)):
            addr = await self._monit_port.get()
            ref_addr = self._cfg._ref_addr[i]

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
    tester = NestedAddrGenTester(dut, cfg)

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