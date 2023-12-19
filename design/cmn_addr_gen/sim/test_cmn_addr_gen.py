from base import *

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

class RandomConfig(BaseConfig):
    def __init__(self):
        self.depth = 5

    def randomize(self):
        pass

class CmnAddrGenTester(BaseTester):
    def __init__(self, dut, cfg):
        self._dut = dut
        self._cfg = cfg
    
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
        self._set_register()
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 1
        await RisingEdge(self._dut.clk)
        self._dut.init_pulse.value = 0

        await RisingEdge(self._dut.clk)
        for i in range(100):
            self._dut.addr_req.value = 1
            await RisingEdge(self._dut.clk)
        self._dut.addr_req.value = 0
    
    def _set_register(self) -> None:
        for i in range(self._cfg.depth):
            self._dut.addr_size[i].value = 10
            self._dut.addr_stride[i].value = 2 * (10**(i))

@cocotb.test()
@intr_handler
async def normal(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = CmnAddrGenTester(dut, cfg)

    tester.init_phase()
    await tester.reset_phase()
    await tester.main_phase()