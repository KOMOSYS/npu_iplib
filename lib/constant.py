import numpy as np

__all__ = ["INT8MIN", "INT8MAX", "INT32MIN", "INT32MAX"]
__all__ += ["UINT8MIN", "UINT8MAX", "UINT32MIN", "UINT32MAX"]
__all__ += ["FLT32MIN", "FLT32MAX"]

INT8MIN = np.iinfo(np.int8).min
INT8MAX = np.iinfo(np.int8).max
INT32MIN = np.iinfo(np.int32).min
INT32MAX = np.iinfo(np.int32).max

UINT8MIN = np.iinfo(np.uint8).min
UINT8MAX = np.iinfo(np.uint8).max
UINT32MIN = np.iinfo(np.uint32).min
UINT32MAX = np.iinfo(np.uint32).max

FLT32MIN = np.finfo(np.float32).min
FLT32MAX = np.finfo(np.float32).max