# Hamming-ECC
***
## Overview
  -  Hamming ECC Encoder/Decoder with Flip-Flop    
      -  1-bit error detection and correction
      -  Data Width Parameterized (Parity Width dependent on Data Width)

### Encoder Pin
  -  input : i_enc_data [DW-1:0]
  -  output : o_parity [PW-1:0]


### Decoder Pin
  -  input : i_dec_data [DW-1:0], i_parity [PW-1:0]
  -  output : o_err_pos [PW-1:0], o_dec_data [DW-1:0]


### Coverage
|             |   BRANCH | COND   | FSM   |   GROUP |   LINE |   SCORE |
|:------------|---------:|:-------|:------|--------:|-------:|--------:|
| Coverage(%) |    97.92 | 100    | --    |    --   |  98.68 |   98.87 |

### Power
|           |   tt_125c |   tt_25c |   tt_85c |
|:----------|----------:|---------:|---------:|
| Power(mW) |     --    |    --    |    --    |

### Area
|**Bit Count**      |512       |
|-------------------|----------|
|**Total cell area**|346.059218|
|**NAND2 area**     |0.058     |
|**Gate Count**     |5966.53824|


***
## Structure

  -  Hamming ECC    
      -  Encoder (hamming_enc) : Encoding Input Data into Syndrome in FIFO (Data + Parity)
      -  Decoder (hamming_dec) : Decoding Syndrome in FIFO into Data

<p align="center"><img src="https://github.com/KOMOSYS/npu_iplib/blob/main/design/hamming_ecc/doc/structure.png?raw=true" width="80%" height="80%"></p>


***
## Function

  -  FIFO 내 (input → output)에서 1-bit Error 발생하면 복원하여 출력
      -  PARITY_FIFO와 PARITY_FIFO 중에서 발생한 1-bit Error는 hamming_dec 내에서 Error 발생 위치 확인 및 수정
      -  DW (Data Width)는 Parameterizing 가능하며, PW (Parity Width)는 각 block 내에서 local parameter로 계산

<p align="center"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/function.png?raw=true" width="80%" height="80%"></p>


***
## Verification Concept

  -  Python Package, Code Model, Verilog RTL 교차 검증 구조

<p align="center"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/verification%20concept.png?raw=true" width="100%" height="100%"></p>


***
## Block Diagram

  -  hamming_enc -> FIFO -> hamming_dec

<p align="center"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/block%20diagram.png?raw=true" width="100%" height="100%"></p>


***
## Code Analysis

  ### Hamming ECC Top Structure

<p align="center"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/code%20analysis_1.png?raw=true" width="40%" height="40%">    <img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/code%20analysis_2.png?raw=true" width="35%" height="35%"></p>

  ### Hamming Encoder : get data position

<p align="left"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/code%20analysis_3.png?raw=true" width="40%" height="40%"></p>

  -  syndrome[11:0] : data & parity 조합

      [0][1][2][3][4][5][6][7][8][9][10][11]

  
  -  get_data_pos[7:0] : 2^n이 아닌 자연수
    
      ex) DW = 8,

      [0][1][2][3][4][5][6][7] = [3,5,6,7,9,10,11,12] = ['0011','0101','0110','0111','1001','1010','1011','1100']

      i=2, get_data_pos[0] / i=4, get_data_pos[1] / i=5, get_data_pos[2] / i=6, get_data_pos[3] / i=8, get_data_pos[4] / i=9, get_data_pos[5] / i=10, get_data_pos[6] / i=11, get_data_pos[7]


  ### Hamming Encoder : get parity

<p align="left"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/code%20analysis_4.png?raw=true" width="40%" height="40%"></p>

  -  data_pos[8][7:0] : data & parity 조합

      [0][1][2][3][4][5][6][7] = [3,5,6,7,9,10,11,12] = ['0011','0101','0110','0111','1001','1010','1011','1100']

  -  r_parity[3:0]

      [0] = i_enc_data[2] ^ i_enc_data[4] ^ i_enc_data[6] ^ i_enc_data[8] ^ i_enc_data[10]

        => 2^0 값이 1(0011, 0101, 0111, 1001, 1011)인 i_enc_data[i] 들의 XOR

      [1] = i_enc_data[2] ^ i_enc_data[5] ^ i_enc_data[6] ^ i_enc_data[9] ^ i_enc_data[10]

        ⇒ 2^1 값이 1(0011, 0110, 0111, 1010, 1011)인 i_enc_data[i] 들의 XOR

      [2] = i_enc_data[4] ^ i_enc_data[5] ^ i_enc_data[6] ^ i_enc_data[11]

        ⇒ 2^2 값이 1(0101, 0110, 0111, 1100)인 i_enc_data[i] 들의 XOR

      [3] = i_enc_data[8] ^ i_enc_data[9] ^ i_enc_data[10] ^ i_enc_data[11]

        ⇒ 1(1001, 1010, 1011, 1100)인 i_enc_data[i] 들의 XOR


  ### Hamming Decoder : get check bit

<p align="left"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/code%20analysis_5.png?raw=true" width="40%" height="40%"></p>

⇒ Encoder에서 data position 구하는 방식과 동일

  -  r_chk_bit[3:0]

      Encoder에서 parity를 구하는 방식으로 먼저 계산한 뒤, 수신한 parity[3:0]의 각 bit를 XOR 계산
   ⇒ new calculated parity[i] ^ received parity[i] = r_chk_bit[i]


  -  chk_bit

      r_chk_bit[3:0]의 각 bit를 OR 계산하여 1-bit error 유무 판단
   

  ### Hamming Decoder : get error bit position & recover it

<p align="left"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/code%20analysis_6.png?raw=true" width="60%" height="60%"></p>  

  -  err_bit[PW-1:0] : 

      Error 발생 bit의 position (i)값


  -  err_bit_enable : 

      Bit Error 발생 여부

      
      -  err_bit_enable = ‘H’ (Bit Error 발생) 이면, err_bit 값에 해당하는 i_dec_data[i]를 flip


***
## Simulation Conclusion

  -  Synthesis Result : Report

      |**Total cell area**|13.600224|
      |-------------------|---------|
      |**NAND2 area**     |0.058    |
      |**Gate Count**     |234      |

     
  -  Simulation Result : Waveform with **NO ERROR**

<p align="center"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/simulation_1.png?raw=true" width="100%" height="100%"></p>  

     
  -  Simulation Result : Waveform with **ERROR**

<p align="center"><img src="https://github.com/KOMOSYS/npu_iplib/blob/315a70ff6fdd299d46a52a199415cfebba73549a/design/hamming_ecc/doc/simulation_2.png?raw=true" width="100%" height="100%"></p>  
