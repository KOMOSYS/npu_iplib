import os
import random
import itertools
import numpy as np
import pandas as pd
from tabulate import tabulate

import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.triggers import Timer, RisingEdge, Combine

from base import *

class RandomConfig(BaseConfig):
    def randomize(self):
        addr_width = 32
        self.depth = random.randint(1, 4)

        while True:
            self.bpad = np.array([random.randrange(0, 3) for _ in range(self.depth)])
            self.size = np.array([random.randrange(1, 32) for _ in range(self.depth)])
            self.apad = np.array([random.randrange(0, 3) for _ in range(self.depth)])
            self.stride = np.array([random.randrange(1, 32) for _ in range(self.depth)])

            if np.prod(self.size) * np.prod(self.stride) < (1<<addr_width):
                break

        self._ref_addr = []
        self._pad_info = []
        for size_idx in itertools.product(*[range(sum(i)) for i in zip(self.bpad, self.size, self.apad)]):
            pad_info = np.where(np.logical_or(size_idx < self.bpad, size_idx >= self.bpad + self.size), True, False)
            self._pad_info.append(True if True in pad_info else False)
            size_idx = np.clip(size_idx - self.bpad, 0, self.size-1)
            self._ref_addr.append(sum(size_idx * self.stride))

        self.bpad = list(self.bpad[::-1])
        self.size = list(self.size[::-1])
        self.apad = list(self.apad[::-1])
        self.stride = list(self.stride[::-1])
        self.base_addr = random.randrange(0, (1<<addr_width) - np.array(self._ref_addr).max())
        self._ref_addr = np.array(self._ref_addr) + self.base_addr

class NestedAddrGenTester(BaseTester):
    def __init__(self, dut, cfg):
        self._dut = dut
        self._cfg = cfg
        self._monit_port = Queue()
    
    def init_phase(self):
        self._dut.reset_n.value = 0
        self._dut.init_pulse.value = 0
        self._dut.base.value = 0
        for i in range(self._dut.DEPTH.value):
            self._dut.pad_before[i].value = 0
            self._dut.size[i].value = 0
            self._dut.pad_after[i].value = 0
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
    
    def _set_register(self) -> None:
        self._dut.base.value = self._cfg.base_addr
        for i in range(self._dut.DEPTH.value):
            self._dut.pad_before[i].value = int(self._cfg.bpad[i]) if i < self._cfg.depth else 0
            self._dut.size[i].value = int(self._cfg.size[i]) if i < self._cfg.depth else 0
            self._dut.pad_after[i].value = int(self._cfg.apad[i]) if i < self._cfg.depth else 0
            self._dut.stride[i].value = int(self._cfg.stride[i]) if i < self._cfg.depth else 0

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
            ispad = self._dut.pad_vld.value != 0
            self._monit_port.put_nowait((addr, ispad))

    async def _checker(self) -> None:
        for i in range(len(self._cfg._ref_addr)):
            addr, ispad = await self._monit_port.get()
            ref_addr = self._cfg._ref_addr[i]
            ref_ispad = self._cfg._pad_info[i]

            compare_datas = {
                "actual": {"addr": str(int(addr, 2)), "ispad": ispad},
                "expected": {"addr": str(ref_addr), "ispad": ref_ispad}
            }
            assert compare_datas["actual"] == compare_datas["expected"], "\n" + tabulate(
                pd.DataFrame(compare_datas), headers="keys", tablefmt="pretty")

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