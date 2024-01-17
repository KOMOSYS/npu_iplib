import random
from base import BaseTester, BaseConfig

import cocotb
from cocotb.triggers import First
from cocotb.triggers import Timer

__all__ = ["dynamic_reset"]

async def dynamic_reset(tester: BaseTester, cfg: BaseConfig, condition=None) -> bool:
    if condition is None:
        start_time = cocotb.utils.get_sim_time('ns')
        await tester.main_phase()
        end_time = cocotb.utils.get_sim_time('ns')
        sim_time = end_time - start_time
        condition = Timer(random.randint(1, round(sim_time)))

    main_phase = cocotb.start_soon(tester.main_phase())
    triggered = await First(main_phase, condition)

    if isinstance(triggered, Timer) or condition.done():
        cocotb.log.info("Dynamic reset triggered")
        tester.clear_coroutines()
        main_phase.kill()
        tester.init_phase()
        await tester.reset_phase()
        cocotb.log.info("Rerun tester main phase")
        await tester.main_phase()
        
