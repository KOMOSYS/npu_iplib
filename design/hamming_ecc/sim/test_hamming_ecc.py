import os
import random
from random import randrange
import itertools
import numpy as np
import pandas as pd

import cocotb
from cocotb.clock import Clock
from cocotb.queue import Queue
from cocotb.triggers import Timer, RisingEdge, Combine

from base import *
from tabulate import tabulate

from functools import reduce
import operator as op

import math
import hamming_codec

# Data Width Parameter Set by User
DW = 512 

# Input Count Parameter Set by User
IC = 3 

class RandomConfig(BaseConfig):
    def randomize(self):
        rand_data_list = [randrange(0, (2**DW)-1) for _ in range(IC)]
        #rand_data_list = np.random.randint(0, (2**DW)-1, size=IC)
        #rand_data_list = rand_data_list.tolist()
        #print(f'rand_data_list = {rand_data_list}')

        # Encoder
        self._enc_input_data_list = self.randomize_input(rand_data_list)
        self._enc_output_parity_list, self._enc_output_data_list, self._enc_output_syndrome_list = self.ref_enc_data(rand_data_list)
        #self._enc_output_parity_list, self._enc_output_data_list, self._enc_output_syndrome_list, self._enc_output_syndrome_list2 = self.ref_enc_data(rand_data_list)

        # Error Insertion
        enc_data_list = self._enc_output_data_list
        enc_parity_list = self._enc_output_parity_list
        err_enc_data_list, err_enc_parity_list, err_enc_syndrome_list = self.err_insert(enc_data_list, enc_parity_list)

        # Decoder
        # -- No Error -- #
        #self._dec_input_parity_list = self._enc_output_parity_list
        #self._dec_input_data_list = self._enc_output_data_list

        # -- Error -- #
        self._dec_input_parity_list = err_enc_parity_list
        self._dec_input_data_list   = err_enc_data_list
        self._dec_input_syndrome_list = self._enc_output_syndrome_list
        self._dec_output_data_code_list = self.ref_dec_data(self._dec_input_parity_list, self._dec_input_data_list, self._dec_input_syndrome_list)
        #self._dec_output_data_package_list, self._dec_output_data_code_list = self.ref_dec_data(self._dec_input_parity_list, self._dec_input_data_list, self._dec_input_syndrome_list)

    def randomize_input(self, rand_data_list):
        # 8bit data -> binary input data (check numpy binary_repr)
        enc_input_data_list= [np.binary_repr(num, width=DW) for num in rand_data_list]
        #cocotb.log.info(enc_input_data_list)

        return enc_input_data_list

    # Reference Hamming Code Encoder/Decoder
    def ref_enc_data(self, rand_data_list):
        enc_output_parity_list    = []  # Code ver.
        enc_output_data_list      = []  # Code ver.
        enc_output_syndrome_list  = []  # Code ver.
        enc_output_syndrome_list2 = []   # Package ver.

        for i in rand_data_list:
            parity, data, syndrome = self.hamming_encoder(i)
            enc_output_parity_list.extend(parity)
            enc_output_data_list.extend(data)
            enc_output_syndrome_list.extend(syndrome)
            #enc_output_syndrome_list2.append(hamming_codec.encode(i, len(data[0])))

        #print('=================================================================')
        #print('===================Encoder=======================================')
        #print('=================================================================')
        #print(f'Input data list  ={rand_data_list}')
        #print(f'Output data list  ={enc_output_data_list}')
        #print(f'Output parity list  ={enc_output_parity_list}')
        #print(f'Expected Encoded Syndrome by python  ={enc_output_syndrome_list}')
        #print(f'Expected Encoded Syndrome by package ={enc_output_syndrome_list2}')
        #print('=================================================================')
        
        return enc_output_parity_list, enc_output_data_list, enc_output_syndrome_list
        #return enc_output_parity_list, enc_output_data_list, enc_output_syndrome_list, enc_output_syndrome_list2

    def err_insert(self, data, parity):
        data_list = []
        parity_list = []
        syndrome = []
        syndrome_list = []
        err_data = []
        err_parity = []
        err_syndrome = []

        for i,j in zip(data, parity):
            data_list.append(i)
            parity_list.append(j)
            d_pos = 0
            p_pos = 0
            data_len = len(i)
            parity_len = len(j)
            syndrome = [None] * (data_len + parity_len)
            
            for k in range(0,len(syndrome)):
                if (1 << int(math.log2(k+1))) == (k+1):
                    syndrome[k] = j[p_pos]
                    p_pos += 1
                else:
                    syndrome[k] = i[d_pos]
                    d_pos += 1
            syndrome = ''.join(syndrome)
            syndrome_list.append(syndrome)
       
        for k in syndrome_list:
            rand_idx = np.random.randint(0, len(k))
            err_inserted_data = k[:rand_idx] + str(1 - int(k[rand_idx])) + k[rand_idx + 1:]
            err_syndrome.append(err_inserted_data)

            err_parity_unit = []
            err_data_unit = []
            
            for l in range(0,len(err_inserted_data)):
                if (1 << int(math.log2(l+1))) == (l+1):
                    err_parity_unit += err_inserted_data[l]
                else:
                    err_data_unit += err_inserted_data[l]
                err_parity_unit = list(err_parity_unit)
                err_data_unit = list(err_data_unit)
            err_parity_unit = ''.join(str(bit) for bit in err_parity_unit)
            err_data_unit = ''.join(str(bit) for bit in err_data_unit)
            err_parity.append(err_parity_unit)
            err_data.append(err_data_unit)

        #print('=================================================================')
        #print('===========ERROR INSERTION=======================================')
        #print('=================================================================')
        #print(f'init data = {data_list}')
        #print(f'err_data = {err_data}')        
        #print(f'init parity = {parity_list}')
        #print(f'err_parity = {err_parity}')        
        #print(f'syndrome_list = {syndrome_list}')
        #print(f'err_syndrome = {err_syndrome}')        
        #print('=================================================================')

        return err_data, err_parity, err_syndrome

    def ref_dec_data(self, parity_list, data_list, syndrome_list):
        #dec_output_data_package_list = []  # Package ver.
        dec_output_data_code_list    = []  # Code ver.

        #for i in syndrome_list:
        #    dec_output_data_package_list.append(hamming_codec.decode(int(i,2), len(i)))

        for j,k in zip(data_list, parity_list):
            dec_output_data_code_list.append(self.hamming_decoder(j,k))

        #print('=================================================================')
        #print('===================Decoder=======================================')
        #print('=================================================================')
        #print(f'Input parity list  ={parity_list}')
        #print(f'Input data list  ={data_list}')
        #print(f'Expected Decoded Data by python  ={dec_output_data_code_list}')
        #print(f'Expected Decoded Data by package ={dec_output_data_package_list}')
        #print('=================================================================')

        return dec_output_data_code_list
        #return dec_output_data_package_list, dec_output_data_code_list


    # Python Code Reference of Hamming Code 
    def hamming_encoder(self, i_data):
        o_parity   = []
        o_data     = []
        o_syndrome = []
        data_pos   = []
        parity_pos = []
        enc_data   = []
        tmp_data   = []
        parity     = []
        p_pos      = 0
        d_pos      = 0

        i = np.binary_repr(i_data, width=DW)
       
        #Parity Width Calculation
        PW = 1
        while True:
            lhs = 2 ** PW 
            rhs = PW + DW + 1

            if lhs >= rhs:
                break

            PW += 1

        #Data Position
        for j in range(0,DW+PW):
            if not ((1 << int(math.log2(j+1))) == (j+1)):
                if len(data_pos) < d_pos + 1:
                    data_pos.extend([None] * (d_pos + 1 - len(data_pos)))
                data_pos[d_pos] = bin(j+1)[2:]
            
                if len(enc_data) < j + 1:
                    enc_data.extend([None] * (j + 1 - len(enc_data)))
                enc_data[j] = i[::-1][d_pos]

                if len(tmp_data) < j + 1:
                    tmp_data.extend([None] * (j + 1 - len(tmp_data)))
                tmp_data[j] = int(enc_data[j])

                d_pos += 1

        #Parity Position
        for k in range(0,DW+PW):
            for l in range(0,PW): # l = ch
                if (2**l) == (k+1): # k = 0,1,3,7
                    s_idx = (2**l) - 1 # start_index = 0,1,3,7
                    index = s_idx
                    toxor = []

                    while index < DW+PW: # 0,1,3,7 
                        block = enc_data[index:index+(2**l)]
                        toxor.extend(block)
                        index += 2 * (2**l)

                    for z in range(1, len(toxor)):
                        if enc_data[s_idx] is None:
                            enc_data[s_idx] = int(toxor[z],2)
                        else:
                            enc_data[s_idx] ^= int(toxor[z],2)
                    parity.append(enc_data[s_idx])
                    tmp_data[s_idx] = enc_data[s_idx]

                    # o_parity appending
                    if l == (PW-1):
                        bin_parity = 0
                        bin_parity = f"{int(''.join(str(bit) for bit in parity), 2)}"
                        bin_parity = bin(int(bin_parity))[2:].zfill(PW)[::-1]
                        o_parity.append(bin_parity)

        # o_syndrome appending
        bin_data = 0
        bin_data = f"{int(''.join(str(bit) for bit in tmp_data[::-1]), 2)}"
        o_data.append(bin(int(i_data))[2:].zfill(DW))
        #format(i_data, f"#0{DW}b")
        o_syndrome.append(bin(int(bin_data))[2:].zfill(DW+PW))

        return o_parity, o_data, o_syndrome

    def hamming_decoder(self, i_data, i_parity):
        o_recovered_data = []
        
        i_d = i_data[::-1]
        i_p = i_parity[::-1]
        # reversed(i_p)

        #Parity Width Calculation
        d_width = len(i_data)
        p_width = len(i_parity)
        
        #Syndrome Generation
        p_pos = 0
        d_pos = 0
        syndrome = [None] * (len(i_d)+len(i_p))

        for i in range(0,len(i_d)+len(i_p)):
            if (1 << int(math.log2(i+1))) == (i+1):
                syndrome[i] = i_p[p_pos]
                p_pos += 1
            else:
                syndrome[i] = i_d[d_pos]
                d_pos += 1

        syndrome = ''.join(syndrome)

        #Check Bit Calculation
        chk_bit = [None] * p_width
        chk_bit_list = []

        for j in range(0,d_width+p_width):
            for k in range(0,p_width):
                if (2**k) == (j+1):
                    s_idx = (2**k) - 1
                    index = s_idx
                    toxor = []

                    while index < d_width+p_width:
                        block = syndrome[index:index+(2**k)]
                        toxor.extend(block)
                        index += 2 * (2**k)
                    for z in range(0, len(toxor)):
                        if (z == 0):
                            chk_bit[k] = int(toxor[z],2)
                        else:
                            chk_bit[k] = chk_bit[k] ^ int(toxor[z],2)
                    chk_bit_list.append(chk_bit[k])

        chk_bit = ''.join(map(str, chk_bit_list[::-1]))
        chk_bit = int(chk_bit,2)
        syndrome = syndrome[:chk_bit-1] + str(int(not bool(int(syndrome[chk_bit-1])))) + syndrome[chk_bit:]

        rd_pos = 0

        for rd_idx in range(0, len(syndrome)):
            if not ((1 << int(math.log2(rd_idx+1))) == (rd_idx+1)):
                if len(o_recovered_data) < rd_idx + 1:
                    o_recovered_data.extend([None] * (rd_idx + 1 - len(o_recovered_data)))
                o_recovered_data[rd_pos] = syndrome[rd_idx]
                rd_pos += 1
        while None in o_recovered_data:
            o_recovered_data.remove(None)
        o_recovered_data = f"{''.join(str(bit) for bit in o_recovered_data[::-1])}"
        return o_recovered_data

class HammingEccEncTester(BaseTester):
    def __init__(self, dut, cfg):
        self._dut = dut
        self._cfg = cfg
        self._enc_monit_port = Queue()
        self._dec_monit_port = Queue()
    
    def init_phase(self):
        self._dut.reset_n.value = 0
        self._dut.i_fifo_wreq.value = 0
        self._dut.i_fifo_rreq.value = 0
        self._dut.i_data.value = 0
        self._dut.u_hamming_ecc.u_hamming_dec.i_dec_data.value = 0
        self._dut.u_hamming_ecc.u_hamming_dec.i_parity.value = 0

    async def reset_phase(self):
        self._dut.reset_n.value = 0
        await Timer(100, units="ns")
        self._dut.reset_n.value = 1

    async def main_phase(self):
        self.start_coroutine(self._driver())
        self.start_coroutine(self._err_driver())
        self.start_coroutine(self._monitor())
        self.start_coroutine(self._enc_checker())
        self.start_coroutine(self._dec_checker())
        await Combine(*self.coroutines)
        
        self.clear_coroutines()    

    async def _driver(self) -> None:
        enc_data = self._cfg._enc_input_data_list
        idx = 0

        while True:
            await RisingEdge(self._dut.clk)
            if self._dut.o_fifo_full.value == 0:
                if idx == len(enc_data):
                    break
                self._dut.i_fifo_wreq.value = 1
                self._dut.i_data.value = int(enc_data[idx], 2)
                idx += 1
            else:
                if self._dut.i_fifo_rreq.value == 1:
                    self._dut.i_fifo_wreq.value = 1
                else:
                    self._dut.i_fifo_wreq.value = 0

            if self._dut.o_fifo_empty.value == 0:
                if self._dut.i_fifo_wreq.value == 0:
                    self._dut.i_fifo_rreq.value = 0 
            else:
                if self._dut.i_fifo_wreq.value == 1:
                    self._dut.i_fifo_rreq.value = 1
        self._dut.i_fifo_wreq.value = 0 
        await RisingEdge(self._dut.clk)
        self._dut.i_fifo_rreq.value = 0

    async def _err_driver(self) -> None:
        dec_parity = self._cfg._dec_input_parity_list
        dec_data   = self._cfg._dec_input_data_list
        idx = 0
                                           
        while True:
            await RisingEdge(self._dut.clk)
            if idx == len(dec_data):
                break
            else:
                if self._dut.i_fifo_rreq.value == 1:
                    self._dut.u_hamming_ecc.u_hamming_dec.i_dec_data.value = int(dec_data[idx],2)
                    self._dut.u_hamming_ecc.u_hamming_dec.i_parity.value = int(dec_parity[idx],2)
                    idx += 1

        await RisingEdge(self._dut.clk)

    async def _monitor(self) -> None:
        self.parity = []
        self.err_pos  = []
        self.dec_data = []

        while True:
            await RisingEdge(self._dut.clk)
            if self._dut.i_fifo_wreq.value == 1:
                self.parity = self._dut.u_hamming_ecc.u_hamming_enc.o_parity.value
                self._enc_monit_port.put_nowait((self.parity))

            if self._dut.r_o_data_monit.value == 1:
                self.err_pos  = self._dut.u_hamming_ecc.u_hamming_dec.o_err_pos.value
                self.dec_data = self._dut.u_hamming_ecc.u_hamming_dec.o_dec_data.value
                self._dec_monit_port.put_nowait((self.err_pos, self.dec_data))

            if self._dut.w_quit_cnt_end.value == 1:
                break
            
    async def _enc_checker(self) -> None:
        for i in range(len(self._cfg._enc_output_data_list)):
            # Python output
            ref_data     = self._cfg._enc_output_data_list[i]
            ref_parity   = self._cfg._enc_output_parity_list[i]
            ref_syndrome = self._cfg._enc_output_syndrome_list[i]
            # Package output
            #ref_syndrome2 = self._cfg._enc_output_syndrome_list2[i]
            # RTL output parity
            enc_parity = await self._enc_monit_port.get()
            compare_data = {
                "Code"            : {"parity":int(ref_parity, 2)},
                "Package and RTL" : {"parity":int(str(enc_parity), 2)},
            }
            assert compare_data["Code"] == compare_data["Package and RTL"], "\n" + tabulate(pd.DataFrame(compare_data), headers="keys", tablefmt="pretty")
            #compare_data = {
            #    "Code"            : {"syndrome":int(ref_syndrome, 2), "parity":int(ref_parity, 2)},
            #    "Package and RTL" : {"syndrome":int(ref_syndrome2, 2), "parity":int(str(enc_parity), 2)},
            #}
            #assert compare_data["Code"] == compare_data["Package and RTL"], "\n" + tabulate(pd.DataFrame(compare_data), headers="keys", tablefmt="pretty")

    async def _dec_checker(self) -> None:
        for i in range(len(self._cfg._dec_output_data_code_list)):
            # Package output data
            #ref_data = self._cfg._dec_output_data_package_list[i]
            # Python output data
            ref_data2 = self._cfg._dec_output_data_code_list[i]
            # RTL output data
            dec_err_pos, dec_data = await self._dec_monit_port.get()
            compare_data = {
                "RTL"     : {"data":dec_data},
                #"Code"    : {"data":int(ref_data, 2)},
                "Package" : {"data":int(ref_data2, 2)},
            }
            assert compare_data["RTL"] == compare_data["Package"], "\n" + tabulate(
                pd.DataFrame(compare_data), headers="keys", tablefmt="pretty")


random_seed = int(os.getenv("RANDOM_SEED")) if os.getenv("RANDOM_SEED") is not None else 1
max_iter = int(os.getenv("MAX_ITER")) if os.getenv("MAX_ITER") is not None else 100

@cocotb.test()
@intr_handler
async def normal(dut):
    clk = cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    cfg = RandomConfig()
    tester = HammingEccEncTester(dut, cfg)

    tester.init_phase()
    await tester.reset_phase()

    for iter in range(1):
        #cocotb.log.info(f"Iteration {iter}")
        set_seed(random_seed+iter)
        cfg.randomize()
        cocotb.log.info(cfg)

        with timeout(10, "m"):
            await tester.main_phase()

    clk.kill()
