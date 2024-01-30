module top #(parameter AW=16, BUFFD=64, ADIM=6)(
    input clk,
    input reset_n,
    input init_pulse,
    input repack_en,
    input [1:0] mode,

    input [AW-1:0] rreq_num,
    input [AW-1:0] raddr_base,
    input [AW-1:0] raddr_size[ADIM],
    input [AW-1:0] raddr_stride[ADIM],
    input [AW-1:0] wreq_num,
    input [AW-1:0] waddr_base,
    input [AW-1:0] waddr_size[ADIM],
    input [AW-1:0] waddr_stride[ADIM],

    input [AW-1:0] packed_dim_size,
    input [AW-1:0] unpacked_dim_size,

    output reg [AW-1:0] raddr,
    output reg raddr_vld,
    input [BUFFD*8-1:0] rdata,
    input rdata_vld,
    output reg [AW-1:0] waddr,
    output reg [BUFFD*8-1:0] wdata,
    output reg wdata_vld,
    output reg finish
);

transposer #(.AW(AW), .BUFFD(BUFFD), .ADIM(ADIM)) u_transposer(.*);
//bind top.u_transposer transposer_assertion #(.AW(AW), .BUFFD(BUFFD)) u_transposer_assertion(.*);
//bind top.u_transposer transposer_coverage #(.AW(AW), .BUFFD(BUFFD)) u_transposer_coverage(.*);

endmodule: top