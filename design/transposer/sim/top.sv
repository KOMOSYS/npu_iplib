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

`ifdef SAIF_ON
`ifndef SAIF_NAME
initial $fatal("SAIF_NAME must be defined");
`else
initial begin
	$set_toggle_region("top.u_transposer");
	$toggle_start();
end
final begin
	$toggle_stop();
	$toggle_report(`SAIF_NAME, 1e-9, "top.u_transposer");
end
`endif
`endif

`ifdef RTL_SIM
transposer #(.AW(AW), .BUFFD(BUFFD), .ADIM(ADIM)) u_transposer(.*);
bind top.u_transposer transposer_assertion #(.AW(AW), .BUFFD(BUFFD)) u_transposer_assertion(.*);
bind top.u_transposer transposer_coverage u_transposer_coverage(.*);
`endif
`ifdef PRE_SIM
transposer u_transposer(
    .clk(clk)
,   .reset_n(reset_n)
,   .init_pulse(init_pulse)
,   .repack_en(repack_en)
,   .mode(mode)
,   .rreq_num(rreq_num)
,   .raddr_base(raddr_base)
,   .raddr_size({>>AW{raddr_size}})
,   .raddr_stride({>>AW{raddr_stride}})
,   .wreq_num(wreq_num)
,   .waddr_base(waddr_base)
,   .waddr_size({>>AW{waddr_size}})
,   .waddr_stride({>>AW{waddr_stride}})
,   .packed_dim_size(packed_dim_size)
,   .unpacked_dim_size(unpacked_dim_size)
,   .raddr(raddr)
,   .raddr_vld(raddr_vld)
,   .rdata(rdata)
,   .rdata_vld(rdata_vld)
,   .waddr(waddr)
,   .wdata(wdata)
,   .wdata_vld(wdata_vld)
,   .finish(finish)
);
`endif
endmodule: top