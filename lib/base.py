import abc
import json
import signal
import abc
import json
import signal
import random
import cocotb
import logging
import functools
import numpy as np
import pandas as pd
from pathlib import Path
from tabulate import tabulate
from contextlib import contextmanager

__all__ = ["BaseConfig", "BaseTester", "set_seed", "intr_handler", "timeout"]

class BaseConfig:
    def freeze(self, *args):
        for name in args:
            self._freeze_list.append(name)

    def unfreeze(self, *args):
        for name in args:
            if name in self._freeze_list:
                self._freeze_list.remove(name)

    def dump(self, path):
        config = {key: str(value) for key, value in self.__dict__.items()}
        config = json.dumps(config, indent=4)
        Path(path).write_text(config)

    def __getattr__(self, name):
        if name == "_freeze_list" and name not in self.__dict__:
            self.__dict__[name] = []
        return self.__dict__[name]

    def __setattr__(self, name, value):
        if name not in self._freeze_list:
            self.__dict__[name] = value

    def __str__(self):
        cfg_dict = {k: v for k, v in self.__dict__.items() if not k.startswith('_')}
        cfg_df = pd.DataFrame({"config": cfg_dict})
        cfg_df = cfg_df.reindex(cfg_dict.keys())
        return tabulate(cfg_df, headers="keys", tablefmt="pretty")


class BaseTester(abc.ABC):
    _coroutines = []
    _file_handlder = logging.FileHandler("vcs.run.log")
    cocotb.log.addHandler(_file_handlder)

    @abc.abstractmethod
    def init_phase(self) -> None:
        raise NotImplementedError()

    @abc.abstractmethod
    async def reset_phase(self) -> None:
        raise NotImplementedError()

    @abc.abstractmethod
    async def main_phase(self) -> None:
        raise NotImplementedError()
    
    @property
    def coroutines(self):
        return self._coroutines
    
    def start_coroutine(self, coro):
        self._coroutines.append(cocotb.start_soon(coro))
        return self._coroutines[-1]
    
    def clear_coroutines(self):
        for coro in self._coroutines:
            try:
                coro.kill()
            except:
                continue
        self._coroutines = []

def set_seed(seed):
    seed = int(seed)
    cocotb.log.info(f"Randomized seed {seed}")
    random.seed(seed)
    np.random.seed(seed)

def _raise_keyboardinterrupt(*args):
    raise KeyboardInterrupt

def intr_handler(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        signal.signal(signal.SIGINT, _raise_keyboardinterrupt)
        signal.signal(signal.SIGTERM, _raise_keyboardinterrupt)
        signal.signal(signal.SIGHUP, _raise_keyboardinterrupt)

        try:
            return func(*args, **kwargs)
        finally:
            pass

    return wrapper

def _raise_timeout(*args):
    raise TimeoutError

@contextmanager
def timeout(time: int, units="s"):
    if type(time) != int or units not in ["s", "m", "h"]:
        raise ValueError("Invalid time unit")

    if units == "m":
        time *= 60
    elif units == "h":
        time *= 3600

    signal.signal(signal.SIGALRM, _raise_timeout)
    signal.alarm(time)
    try:
        yield
    finally:
        signal.alarm(0)
