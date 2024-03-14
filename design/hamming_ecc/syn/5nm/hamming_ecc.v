/////////////////////////////////////////////////////////////
// Created by: Synopsys DC Ultra(TM) in wire load mode
// Version   : R-2020.09-SP4
// Date      : Thu Mar 14 17:21:36 2024
/////////////////////////////////////////////////////////////


module SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW10_0 ( CLK, EN, ENCLK, TE );
  input CLK, EN, TE;
  output ENCLK;
  wire   n1;

  PREICGL_X1N_A6ZTR_C10 latch ( .CK(CLK), .E(EN), .SE(n1), .ECK(ENCLK) );
  TIELO_X1N_A6ZTR_C10 U1 ( .Y(n1) );
endmodule


module SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW10_2 ( CLK, EN, ENCLK, TE );
  input CLK, EN, TE;
  output ENCLK;
  wire   n3;

  PREICGL_X1N_A6ZTR_C10 latch ( .CK(CLK), .E(EN), .SE(n3), .ECK(ENCLK) );
  TIELO_X1N_A6ZTR_C10 U1 ( .Y(n3) );
endmodule


module SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW10_1 ( CLK, EN, ENCLK, TE );
  input CLK, EN, TE;
  output ENCLK;
  wire   n3;

  PREICGL_X1N_A6ZTR_C10 latch ( .CK(CLK), .E(EN), .SE(n3), .ECK(ENCLK) );
  TIELO_X1N_A6ZTR_C10 U1 ( .Y(n3) );
endmodule


module fifo_FC1_FD2_FW10 ( clk, reset_n, ffbwreq, ffbrreq, ffbdi, ffbempty, 
        ffbfull, ffbvcnt, ffbdo );
  input [9:0] ffbdi;
  output [1:0] ffbvcnt;
  output [9:0] ffbdo;
  input clk, reset_n, ffbwreq, ffbrreq;
  output ffbempty, ffbfull;
  wire   \*Logic0* , ffbfull, incrcnt, \rcnt[0] , N11, N32, \mb[0][9] ,
         \mb[0][8] , \mb[0][7] , \mb[0][6] , \mb[0][5] , \mb[0][4] ,
         \mb[0][3] , \mb[0][2] , \mb[0][1] , \mb[0][0] , \mb[1][9] ,
         \mb[1][8] , \mb[1][7] , \mb[1][6] , \mb[1][5] , \mb[1][4] ,
         \mb[1][3] , \mb[1][2] , \mb[1][1] , \mb[1][0] , N33, N34, N36, N37,
         N38, N39, N40, N41, N42, N43, N44, N45, net173, net179, net184, n7,
         n8, n9, n11, n1, n2, n3, n4, n5, n6;
  tri   [9:0] ffbdi;
  tri   [9:0] ffbdo;
  assign ffbvcnt[1] = ffbfull;

  DFFRPQA_X1N_A6ZTR_C10 \vcnt_reg[0]  ( .D(n9), .CK(clk), .R(n11), .Q(
        ffbvcnt[0]) );
  DFFRPQA_X1N_A6ZTR_C10 \vcnt_reg[1]  ( .D(n8), .CK(clk), .R(n11), .Q(ffbfull)
         );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[9]  ( .D(N36), .CK(net173), .R(n11), .Q(
        ffbdo[9]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[8]  ( .D(N37), .CK(net173), .R(n11), .Q(
        ffbdo[8]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[7]  ( .D(N38), .CK(net173), .R(n11), .Q(
        ffbdo[7]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[6]  ( .D(N39), .CK(net173), .R(n11), .Q(
        ffbdo[6]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[5]  ( .D(N40), .CK(net173), .R(n11), .Q(
        ffbdo[5]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[4]  ( .D(N41), .CK(net173), .R(n11), .Q(
        ffbdo[4]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[3]  ( .D(N42), .CK(net173), .R(n11), .Q(
        ffbdo[3]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[2]  ( .D(N43), .CK(net173), .R(n11), .Q(
        ffbdo[2]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[1]  ( .D(N44), .CK(net173), .R(n11), .Q(
        ffbdo[1]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[0]  ( .D(N45), .CK(net173), .R(n11), .Q(
        ffbdo[0]) );
  DFFRPQA_X1N_A6ZTR_C10 \wcnt_reg[0]  ( .D(n7), .CK(clk), .R(n11), .Q(N32) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][9]  ( .D(ffbdi[9]), .CK(net179), .Q(
        \mb[0][9] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][8]  ( .D(ffbdi[8]), .CK(net179), .Q(
        \mb[0][8] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][7]  ( .D(ffbdi[7]), .CK(net179), .Q(
        \mb[0][7] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][6]  ( .D(ffbdi[6]), .CK(net179), .Q(
        \mb[0][6] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][5]  ( .D(ffbdi[5]), .CK(net179), .Q(
        \mb[0][5] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][4]  ( .D(ffbdi[4]), .CK(net179), .Q(
        \mb[0][4] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][3]  ( .D(ffbdi[3]), .CK(net179), .Q(
        \mb[0][3] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][2]  ( .D(ffbdi[2]), .CK(net179), .Q(
        \mb[0][2] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][1]  ( .D(ffbdi[1]), .CK(net179), .Q(
        \mb[0][1] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][0]  ( .D(ffbdi[0]), .CK(net179), .Q(
        \mb[0][0] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][9]  ( .D(ffbdi[9]), .CK(net184), .Q(
        \mb[1][9] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][8]  ( .D(ffbdi[8]), .CK(net184), .Q(
        \mb[1][8] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][7]  ( .D(ffbdi[7]), .CK(net184), .Q(
        \mb[1][7] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][6]  ( .D(ffbdi[6]), .CK(net184), .Q(
        \mb[1][6] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][5]  ( .D(ffbdi[5]), .CK(net184), .Q(
        \mb[1][5] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][4]  ( .D(ffbdi[4]), .CK(net184), .Q(
        \mb[1][4] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][3]  ( .D(ffbdi[3]), .CK(net184), .Q(
        \mb[1][3] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][2]  ( .D(ffbdi[2]), .CK(net184), .Q(
        \mb[1][2] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][1]  ( .D(ffbdi[1]), .CK(net184), .Q(
        \mb[1][1] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][0]  ( .D(ffbdi[0]), .CK(net184), .Q(
        \mb[1][0] ) );
  DFFRPQA_X1N_A6ZTR_C10 \rcnt_reg[0]  ( .D(N11), .CK(net173), .R(n11), .Q(
        \rcnt[0] ) );
  TIELO_X1N_A6ZTR_C10 U3 ( .Y(\*Logic0* ) );
  INV_X1N_A6ZTR_C10 U4 ( .A(reset_n), .Y(n11) );
  NOR2_X1N_A6ZTR_C10 U5 ( .A(ffbvcnt[0]), .B(ffbfull), .Y(ffbempty) );
  NAND2XB_X1N_A6ZTR_C10 U6 ( .BN(ffbfull), .A(ffbwreq), .Y(n6) );
  NAND2XB_X1N_A6ZTR_C10 U7 ( .BN(ffbempty), .A(ffbrreq), .Y(n4) );
  AO21_X1N_A6ZTR_C10 U8 ( .A0(n6), .A1(n4), .B0(ffbvcnt[0]), .Y(n3) );
  NAND2_X1N_A6ZTR_C10 U9 ( .A(ffbrreq), .B(n6), .Y(n1) );
  OAI211_X1N_A6ZTR_C10 U10 ( .A0(ffbrreq), .A1(n6), .B0(ffbvcnt[0]), .C0(n1), 
        .Y(n2) );
  NAND2_X1N_A6ZTR_C10 U11 ( .A(n3), .B(n2), .Y(n9) );
  NOR2XB_X1N_A6ZTR_C10 U12 ( .BN(N32), .A(n6), .Y(N33) );
  NOR2_X1N_A6ZTR_C10 U13 ( .A(N32), .B(n6), .Y(N34) );
  INV_X1N_A6ZTR_C10 U14 ( .A(n4), .Y(incrcnt) );
  INV_X1N_A6ZTR_C10 U15 ( .A(\rcnt[0] ), .Y(N11) );
  AO21A1AI2_X1N_A6ZTR_C10 U16 ( .A0(n4), .A1(ffbwreq), .B0(ffbfull), .C0(n3), 
        .Y(n5) );
  INV_X1N_A6ZTR_C10 U17 ( .A(n5), .Y(n8) );
  MXT2_X1N_A6ZTR_C10 U18 ( .A(\mb[0][0] ), .B(\mb[1][0] ), .S0(\rcnt[0] ), .Y(
        N45) );
  MXT2_X1N_A6ZTR_C10 U19 ( .A(\mb[0][1] ), .B(\mb[1][1] ), .S0(\rcnt[0] ), .Y(
        N44) );
  MXT2_X1N_A6ZTR_C10 U20 ( .A(\mb[0][2] ), .B(\mb[1][2] ), .S0(\rcnt[0] ), .Y(
        N43) );
  MXT2_X1N_A6ZTR_C10 U21 ( .A(\mb[0][3] ), .B(\mb[1][3] ), .S0(\rcnt[0] ), .Y(
        N42) );
  MXT2_X1N_A6ZTR_C10 U22 ( .A(\mb[0][4] ), .B(\mb[1][4] ), .S0(\rcnt[0] ), .Y(
        N41) );
  MXT2_X1N_A6ZTR_C10 U23 ( .A(\mb[0][5] ), .B(\mb[1][5] ), .S0(\rcnt[0] ), .Y(
        N40) );
  MXT2_X1N_A6ZTR_C10 U24 ( .A(\mb[0][6] ), .B(\mb[1][6] ), .S0(\rcnt[0] ), .Y(
        N39) );
  MXT2_X1N_A6ZTR_C10 U25 ( .A(\mb[0][7] ), .B(\mb[1][7] ), .S0(\rcnt[0] ), .Y(
        N38) );
  MXT2_X1N_A6ZTR_C10 U26 ( .A(\mb[0][8] ), .B(\mb[1][8] ), .S0(\rcnt[0] ), .Y(
        N37) );
  MXT2_X1N_A6ZTR_C10 U27 ( .A(\mb[0][9] ), .B(\mb[1][9] ), .S0(\rcnt[0] ), .Y(
        N36) );
  AO21_X1N_A6ZTR_C10 U28 ( .A0(N32), .A1(n6), .B0(N34), .Y(n7) );
  SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW10_0 clk_gate_rcnt_reg ( .CLK(clk), .EN(
        incrcnt), .ENCLK(net173), .TE(\*Logic0* ) );
  SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW10_2 \clk_gate_mb_reg[0]  ( .CLK(clk), 
        .EN(N34), .ENCLK(net179), .TE(\*Logic0* ) );
  SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW10_1 \clk_gate_mb_reg[1]  ( .CLK(clk), 
        .EN(N33), .ENCLK(net184), .TE(\*Logic0* ) );
endmodule


module SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW4_0 ( CLK, EN, ENCLK, TE );
  input CLK, EN, TE;
  output ENCLK;
  wire   n1;

  PREICGL_X1N_A6ZTR_C10 latch ( .CK(CLK), .E(EN), .SE(n1), .ECK(ENCLK) );
  TIELO_X1N_A6ZTR_C10 U1 ( .Y(n1) );
endmodule


module SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW4_2 ( CLK, EN, ENCLK, TE );
  input CLK, EN, TE;
  output ENCLK;
  wire   n3;

  PREICGL_X1N_A6ZTR_C10 latch ( .CK(CLK), .E(EN), .SE(n3), .ECK(ENCLK) );
  TIELO_X1N_A6ZTR_C10 U1 ( .Y(n3) );
endmodule


module SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW4_1 ( CLK, EN, ENCLK, TE );
  input CLK, EN, TE;
  output ENCLK;
  wire   n3;

  PREICGL_X1N_A6ZTR_C10 latch ( .CK(CLK), .E(EN), .SE(n3), .ECK(ENCLK) );
  TIELO_X1N_A6ZTR_C10 U1 ( .Y(n3) );
endmodule


module fifo_FC1_FD2_FW4 ( clk, reset_n, ffbwreq, ffbrreq, ffbdi, ffbempty, 
        ffbfull, ffbvcnt, ffbdo );
  input [3:0] ffbdi;
  output [1:0] ffbvcnt;
  output [3:0] ffbdo;
  input clk, reset_n, ffbwreq, ffbrreq;
  output ffbempty, ffbfull;
  wire   \*Logic0* , ffbfull, incrcnt, \rcnt[0] , N11, N32, \mb[0][3] ,
         \mb[0][2] , \mb[0][1] , \mb[0][0] , \mb[1][3] , \mb[1][2] ,
         \mb[1][1] , \mb[1][0] , N33, N34, N36, N37, N38, N39, net145, net151,
         net156, n7, n8, n9, n11, n1, n2, n3, n4, n5, n6;
  tri   [3:0] ffbdi;
  tri   [3:0] ffbdo;
  assign ffbvcnt[1] = ffbfull;

  DFFRPQA_X1N_A6ZTR_C10 \vcnt_reg[0]  ( .D(n9), .CK(clk), .R(n11), .Q(
        ffbvcnt[0]) );
  DFFRPQA_X1N_A6ZTR_C10 \rcnt_reg[0]  ( .D(N11), .CK(net145), .R(n11), .Q(
        \rcnt[0] ) );
  DFFRPQA_X1N_A6ZTR_C10 \vcnt_reg[1]  ( .D(n8), .CK(clk), .R(n11), .Q(ffbfull)
         );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[3]  ( .D(N36), .CK(net145), .R(n11), .Q(
        ffbdo[3]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[2]  ( .D(N37), .CK(net145), .R(n11), .Q(
        ffbdo[2]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[1]  ( .D(N38), .CK(net145), .R(n11), .Q(
        ffbdo[1]) );
  DFFRPQA_X1N_A6ZTR_C10 \ffbdo_reg[0]  ( .D(N39), .CK(net145), .R(n11), .Q(
        ffbdo[0]) );
  DFFRPQA_X1N_A6ZTR_C10 \wcnt_reg[0]  ( .D(n7), .CK(clk), .R(n11), .Q(N32) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][3]  ( .D(ffbdi[3]), .CK(net151), .Q(
        \mb[0][3] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][2]  ( .D(ffbdi[2]), .CK(net151), .Q(
        \mb[0][2] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][1]  ( .D(ffbdi[1]), .CK(net151), .Q(
        \mb[0][1] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[0][0]  ( .D(ffbdi[0]), .CK(net151), .Q(
        \mb[0][0] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][3]  ( .D(ffbdi[3]), .CK(net156), .Q(
        \mb[1][3] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][2]  ( .D(ffbdi[2]), .CK(net156), .Q(
        \mb[1][2] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][1]  ( .D(ffbdi[1]), .CK(net156), .Q(
        \mb[1][1] ) );
  DFFQA_X1N_A6ZTR_C10 \mb_reg[1][0]  ( .D(ffbdi[0]), .CK(net156), .Q(
        \mb[1][0] ) );
  TIELO_X1N_A6ZTR_C10 U3 ( .Y(\*Logic0* ) );
  INV_X1N_A6ZTR_C10 U4 ( .A(reset_n), .Y(n11) );
  INV_X1N_A6ZTR_C10 U5 ( .A(\rcnt[0] ), .Y(N11) );
  NOR2_X1N_A6ZTR_C10 U6 ( .A(ffbvcnt[0]), .B(ffbfull), .Y(ffbempty) );
  NAND2XB_X1N_A6ZTR_C10 U7 ( .BN(ffbfull), .A(ffbwreq), .Y(n6) );
  NAND2XB_X1N_A6ZTR_C10 U8 ( .BN(ffbempty), .A(ffbrreq), .Y(n4) );
  AO21_X1N_A6ZTR_C10 U9 ( .A0(n6), .A1(n4), .B0(ffbvcnt[0]), .Y(n3) );
  NAND2_X1N_A6ZTR_C10 U10 ( .A(ffbrreq), .B(n6), .Y(n1) );
  OAI211_X1N_A6ZTR_C10 U11 ( .A0(ffbrreq), .A1(n6), .B0(ffbvcnt[0]), .C0(n1), 
        .Y(n2) );
  NAND2_X1N_A6ZTR_C10 U12 ( .A(n3), .B(n2), .Y(n9) );
  NOR2XB_X1N_A6ZTR_C10 U13 ( .BN(N32), .A(n6), .Y(N33) );
  NOR2_X1N_A6ZTR_C10 U14 ( .A(N32), .B(n6), .Y(N34) );
  INV_X1N_A6ZTR_C10 U15 ( .A(n4), .Y(incrcnt) );
  AO21A1AI2_X1N_A6ZTR_C10 U16 ( .A0(n4), .A1(ffbwreq), .B0(ffbfull), .C0(n3), 
        .Y(n5) );
  INV_X1N_A6ZTR_C10 U17 ( .A(n5), .Y(n8) );
  MXT2_X1N_A6ZTR_C10 U18 ( .A(\mb[0][0] ), .B(\mb[1][0] ), .S0(\rcnt[0] ), .Y(
        N39) );
  MXT2_X1N_A6ZTR_C10 U19 ( .A(\mb[0][1] ), .B(\mb[1][1] ), .S0(\rcnt[0] ), .Y(
        N38) );
  MXT2_X1N_A6ZTR_C10 U20 ( .A(\mb[0][2] ), .B(\mb[1][2] ), .S0(\rcnt[0] ), .Y(
        N37) );
  MXT2_X1N_A6ZTR_C10 U21 ( .A(\mb[0][3] ), .B(\mb[1][3] ), .S0(\rcnt[0] ), .Y(
        N36) );
  AO21_X1N_A6ZTR_C10 U22 ( .A0(N32), .A1(n6), .B0(N34), .Y(n7) );
  SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW4_0 clk_gate_rcnt_reg ( .CLK(clk), .EN(
        incrcnt), .ENCLK(net145), .TE(\*Logic0* ) );
  SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW4_2 \clk_gate_mb_reg[0]  ( .CLK(clk), 
        .EN(N34), .ENCLK(net151), .TE(\*Logic0* ) );
  SNPS_CLOCK_GATE_HIGH_fifo_FC1_FD2_FW4_1 \clk_gate_mb_reg[1]  ( .CLK(clk), 
        .EN(N33), .ENCLK(net156), .TE(\*Logic0* ) );
endmodule


module hamming_ecc ( clk, reset_n, i_fifo_wreq, i_fifo_rreq, i_data, 
        o_fifo_empty, o_fifo_full, o_data );
  input [9:0] i_data;
  output [9:0] o_data;
  input clk, reset_n, i_fifo_wreq, i_fifo_rreq;
  output o_fifo_empty, o_fifo_full;

  tri   [9:0] i_data;
  tri   [9:0] o_data;
  tri   [3:0] w_parity1;
  tri   [9:0] w_data2;
  tri   [3:0] w_parity2;

  hamming_enc u_hamming_enc ( .i_enc_data(i_data), .o_parity(w_parity1) );
  fifo_FC1_FD2_FW10 u_data_fifo ( .clk(clk), .reset_n(reset_n), .ffbwreq(
        i_fifo_wreq), .ffbrreq(i_fifo_rreq), .ffbdi(i_data), .ffbempty(
        o_fifo_empty), .ffbfull(o_fifo_full), .ffbdo(w_data2) );
  fifo_FC1_FD2_FW4 u_parity_fifo ( .clk(clk), .reset_n(reset_n), .ffbwreq(
        i_fifo_wreq), .ffbrreq(i_fifo_rreq), .ffbdi(w_parity1), .ffbdo(
        w_parity2) );
  hamming_dec u_hamming_dec ( .i_dec_data(w_data2), .i_parity(w_parity2), 
        .o_dec_data(o_data) );
endmodule

