import numpy as np
from typing import Union
from functools import reduce

__all__ = ["np2binstr", "np2mem", "mem_reshape", "mem_hstack", "mem_vstack", "binstr2hexstr", "fill_zero"]

def np2binstr(data: np.ndarray, width: int = None) -> np.ndarray:
    if not isinstance(data, np.ndarray):
        raise TypeError("Input type must be numpy array")
    
    org_bitwidth = data.dtype.itemsize * 8
    if width is None:
        width = org_bitwidth
    elif width > org_bitwidth:
        raise ValueError(f"Input width {width} is larger than original dtype width {org_bitwidth}")

    if np.issubdtype(data.dtype, np.floating):
        if data.dtype == np.float32:
            data = data.view(np.uint32)
        else:
            raise TypeError("Floating point to binstr only supports np.float32")
        
        vectorized_func = np.vectorize(lambda x : np.binary_repr(x, width=org_bitwidth)[:width])
    else:
        vectorized_func = np.vectorize(lambda x : np.binary_repr(x, width=width))

    return vectorized_func(data)

def np2mem(data: np.ndarray, width: int = None, base="bin") -> np.ndarray:
    if not isinstance(data, np.ndarray):
        raise TypeError("Input type must be numpy array")
    if base not in ["bin", 'hex']:
        raise ValueError("Base only supports bin and hex")

    data = data.reshape(-1, data.shape[-1])
    mem = np2binstr(data, width=width)
    if base == "bin":
        mem = ["".join(word[::-1]) for word in mem]
    else:
        mem_width = len(mem[0]) * len(mem[0][0])
        mem = [binstr2hexstr("".join(word[::-1]), mem_width) for word in mem]
    return mem

def mem_reshape(mem, mem_width):
    if not _chk_mem_vld(mem):
        raise TypeError("Data is not mem type")
    
    org_mem_width = len(mem[0])
    org_mem_depth = len(mem)
    result = []
    if mem_width > org_mem_width and not (mem_width % org_mem_width):
        chunk_size = mem_width // org_mem_width
        for i in range(0, org_mem_depth, chunk_size):
            chunk = mem[i:i+chunk_size] if i+chunk_size < org_mem_depth else mem[i:]
            result.append("".join(chunk[::-1]).zfill(mem_width))
    elif org_mem_width > mem_width and not (org_mem_width % mem_width):
        for word in mem:
            result += [word[i:i+mem_width] for i in range(0, org_mem_width, mem_width)][::-1]
    elif mem_width == org_mem_width:
        result = mem
    else:
        raise ValueError(f"Cannot reshape mem width {org_mem_width} to {mem_width}")
    return result

def mem_hstack(mems: Union[list, tuple]):
    for idx, mem in enumerate(mems):
        if not _chk_mem_vld(mem):
            raise TypeError(f"{idx}th data is not mem type")

    depth = [len(i) for i in mems]
    if len(set(depth)) != 1:
        raise ValueError(f"Memory depth differs {depth}")
    return ["".join(list(word)[::-1]) for word in zip(*mems)]

def mem_vstack(mems: Union[list, tuple]):
    for idx, mem in enumerate(mems):
        if not _chk_mem_vld(mem):
            raise TypeError(f"{idx}th data is not mem type")

    mem_width = [len(mem[0]) for mem in mems] 
    if len(set(mem_width)) != 1:
        raise ValueError(f"Memory width differs {mem_width}")
    return reduce(lambda x, y: x + y, mems)

def _chk_mem_vld(mem):
    if np.array(mem).ndim != 1:
        raise ValueError(f"Memory dimension is not 1")
    data_t = [type(i) for i in mem]
    data_w = [len(i) for i in mem]

    if len(set(data_t)) != 1 or data_t[0] != str:
        return 0
    elif len(set(data_w)) != 1:
        return 0
    else:
        return 1

def binstr2hexstr(data: Union[str, np.ndarray], width=None) -> Union[str, np.ndarray]:
    if isinstance(data, str):
        if width is None:
            return f"{int(data, 2):x}"
        else:
            return f"{int(data, 2):x}".zfill(width // 4)
    else:
        if width is None:
            vectorized_func = np.vectorize(lambda x : f"{int(x, 2):x}")
        else:
            vectorized_func = np.vectorize(lambda x : f"{int(x, 2):x}".zfill(width // 4))
        return vectorized_func(data)

def fill_zero(data: np.ndarray, shape: Union[tuple, list], append: bool = True, constant: int = 0) ->np.ndarray:
    if (org_ndim := data.ndim) != len(shape):
        raise ValueError("Data dimension differs with shape dimension")
    if (org_shape := data.shape) > tuple(shape):
        raise ValueError(f"Cannot convert {org_shape} to {shape}")
    
    if append:
        pad_width = list(zip(np.zeros(org_ndim, dtype=int), np.array(shape) - np.array(org_shape)))
    else:
        pad_width = list(zip(np.array(shape) - np.array(org_shape), np.zeros(org_ndim, dtype=int)))

    return np.pad(data, pad_width, mode='constant', constant_values=constant)
