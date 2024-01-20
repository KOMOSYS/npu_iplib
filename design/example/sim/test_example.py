import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, Combine

from base import *

class RandomConfig(BaseConfig):
    def randomize(self):
        pass

class ExampleTester(BaseTester):
    def __init__(self, dut, cfg):
        self._dut = dut
        self._cfg = cfg
    
    def init_phase(self):
        self._dut.reset_n.value = 0

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

    async def _driver(self) -> None:
        self._set_register()

    async def _monitor(self) -> None:
        pass

    async def _checker(self) -> None:
        pass

    def _set_register(self) -> None:
        pass

                
random_seed = int(os.getenv("RANDOM_SEED")) if os.getenv("RANDOM_SEED") is not None else 1
max_iter = int(os.getenv("MAX_ITER")) if os.getenv("MAX_ITER") is not None else 100

@cocotb.test()
@intr_handler
async def normal(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = ExampleTester(dut, cfg)

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