import itertools
import numpy as np
from math import ceil
from functools import reduce

def to_mem(array, wordSize):
    if array.shape[-1] > 64 and array.shape[-1] % 64:
        pad_shape = [0] * (array.ndim-1) + [64 - ceil(array.shape[-1] % 64)]
        pad_info = list(zip(np.zeros(len(pad_shape), dtype=int), pad_shape))
        array = np.pad(array, pad_width=pad_info, mode='constant', constant_values=0)
        return array.reshape(-1, 64)
    else:
        return array.reshape(-1, array.shape[-1])

def get_stride_info(shape, idx):
    if idx == len(shape) - 1:
        return None
    else:
        return reduce(lambda x, y: x*y, shape[idx+1:-1], ceil(shape[-1] / 64))

def addr_gen(addr_info):
    for indices in itertools.product(*[range(info["size"]) for info in addr_info]):
        stride = [i["stride"] for i in addr_info]
        yield sum([i*j for i, j in zip(indices, stride)])

if __name__ == "__main__":
    for seed in range(100):
        print(f"\nIteration {seed}")
        np.random.seed(seed)
        dim = 3
        wordSize = 64

        # Randomize input, transpose_info and get reference
        in_shape = np.random.randint(60, 70, size=dim)
        in_data = np.random.randint(-128, 127, size=in_shape)
        trp_info = list(range(dim))
        np.random.shuffle(trp_info)
        ref_data = in_data.transpose(*trp_info)

        # Data to mem type
        in_data_mem = to_mem(in_data, wordSize)
        ref_data_mem = to_mem(ref_data, wordSize)

        packedDimIdx = trp_info[-1]
        unpackedDimIdx = max(trp_info)

        repack_en = packedDimIdx != unpackedDimIdx

        rd_info = []
        wr_info = []
        for i in range(dim):
            if i != unpackedDimIdx and i != packedDimIdx:
                rd_info.append({"dim": i,
                                "size": in_data.shape[i],
                                "stride": get_stride_info(in_data.shape, i)})
                wr_info.append({"dim": i,
                                "size": in_data.shape[i],
                                "stride": get_stride_info(ref_data.shape, trp_info.index(i))})

        print(f"Input Shape : {in_data.shape}")
        print(f"Output Shape : {ref_data.shape}")
        print(f"Read Address Gen Info : {rd_info}")
        print(f"Write Address Gen Info : {wr_info}")

        rd_addr_gen = addr_gen(rd_info)
        wr_addr_gen = addr_gen(wr_info)

        comp_iter = 1
        for i in rd_info:
            comp_iter *= i["size"]

        if not repack_en:
            for _ in range(comp_iter):
                rd_base_addr = next(rd_addr_gen)
                wr_base_addr = next(wr_addr_gen)
                assert (in_data_mem[rd_base_addr] == ref_data_mem[wr_base_addr]).all()
        else:
            rd_size = in_data.shape[packedDimIdx]
            rd_stride = get_stride_info(in_data.shape, packedDimIdx)
            wr_size = in_data.shape[unpackedDimIdx]
            wr_stride = get_stride_info(ref_data.shape, trp_info.index(unpackedDimIdx))

            for _ in range(comp_iter):
                rd_base_addr = next(rd_addr_gen)
                wr_base_addr = next(wr_addr_gen)

                for w in range(ceil(wr_size / wordSize)):
                    for r in range(ceil(rd_size / wordSize)):
                        rd_cnt = wordSize if (r+1) * wordSize <= rd_size else rd_size % wordSize
                        wr_cnt = wordSize if (w+1) * wordSize <= wr_size else wr_size % wordSize

                        src_array = []
                        for i in range(rd_cnt):
                            rd_addr = rd_base_addr + i*rd_stride + r*wordSize*rd_stride + w
                            src_data = in_data_mem[rd_addr]
                            src_array.append(src_data)
                        src_array = np.array(src_array).T

                        for i in range(wr_cnt):
                            src_data = src_array[i][:rd_cnt]
                            wr_addr = wr_base_addr + i*wr_stride + w*wordSize*wr_stride + r
                            ref_data = ref_data_mem[wr_addr][:rd_cnt]
                            if (src_data != ref_data).all():
                                print("-------------------------------------------------------------------------------")
                                print(src_data)
                                print("-------------------------------------------------------------------------------")
                                print(ref_data)
                                exit()
