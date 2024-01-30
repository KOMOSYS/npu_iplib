import numpy as np
from math import ceil
from pathlib import Path

__all__ = ["Memory"]

class Memory:
    def __init__(self, data: np.ndarray, width: int = 512, append_last: bool = True):
        if not isinstance(data, np.ndarray):
            raise TypeError("Input type must be numpy array")
        dsize = data.dtype.itemsize
        if width % (dsize * 8):
            raise ValueError(f"Memory width({width}) must be multiple of dsize({self._dsize * 8})")
        self._data = data
        self._width = width
        self._dsize = dsize
        self._append_last = append_last
        self._mem = self._get_mem()
    
    def __getitem__(self, addr):
        return "".join(self._np2binstr(self._mem[addr])[::-1])
    
    def get_mask(self, addr: int) -> str:
        vld_bit = self._get_vld_byte(addr) * 8
        return ("1" * vld_bit).zfill(self._width)

    def _get_vld_byte(self, addr: int) -> int:
        if addr >= self.depth:
            raise ValueError("Address is larger than memory depth")
        dnum_in_word = self._width // (self._dsize * 8)
        if self._append_last:
            chunk_size = np.prod(self._data.shape) // self._data.shape[-1]
        else:
            chunk_size = ceil(self._data.shape[-1] / dnum_in_word)
        
        if addr % chunk_size == chunk_size - 1:
            if self._data.shape[-1] % dnum_in_word:
                return (self._data.shape[-1] % dnum_in_word) * self._dsize
            else:
                return self._width // 8
        else:
            return self._width // 8
    
    def dump(self, fpath="./dump.hex"):
        Path(fpath).write_text("\n".join([format(int(self[i], 2), f"0{self._width // 4}x") for i in range(self.depth)]))

    @property
    def mem(self):
        return self._mem

    @property
    def depth(self):
        return len(self._mem)

    @property
    def width(self):
        return self._width

    def _get_mem(self) -> np.ndarray:
        dnum_in_word = self._width // (self._dsize * 8)
        shape = [*self._data.shape[:-1], ceil(self._data.shape[-1] / dnum_in_word) * dnum_in_word]
        pad_width = list(zip(np.zeros(self._data.ndim, dtype=int), np.array(shape) - np.array(self._data.shape)))

        mem = np.pad(self._data, pad_width, mode='constant', constant_values=0)
        if self._append_last:
            mem = [mem[..., i:i+dnum_in_word] for i in range(0, mem.shape[-1], dnum_in_word)]
        return np.array(mem).reshape(-1, dnum_in_word)
    
    def _np2binstr(self, data: np.ndarray) -> str:
        if not isinstance(data, np.ndarray):
            raise TypeError("Input type must be numpy array")

        if np.issubdtype(data.dtype, np.floating):
            if data.dtype == np.float32:
                data = data.view(np.uint32)
            else:
                raise TypeError("Floating point to binstr only supports np.float32")
        vectorized_func = np.vectorize(lambda x : np.binary_repr(x, width=data.dtype.itemsize * 8))
        return vectorized_func(data)