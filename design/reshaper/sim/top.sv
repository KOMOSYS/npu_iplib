module top #(parameter AW=16, DW=512, BUFFW=512*3, ADIM=6, MEM_DELAY=8)(
    input clk,
    input reset_n,
    input init_pulse,

    input [AW-1:0] rreq_num,
    input [AW-1:0] raddr_base,
    input [AW-1:0] raddr_size[ADIM],
    input [AW-1:0] raddr_stride[ADIM],
    input [AW-1:0] wreq_num,
    input [AW-1:0] waddr_base,
    input [AW-1:0] waddr_size[ADIM],
    input [AW-1:0] waddr_stride[ADIM],
    
    input [AW-1:0] rdata_size,
    input [AW-1:0] wdata_size,

    output reg [AW-1:0] raddr,
    output reg raddr_vld,
    input [DW-1:0] rdata,
    input rdata_vld,
    output reg [AW-1:0] waddr,
    output reg [DW-1:0] wdata,
    output reg wdata_vld,
    output reg finish
);

`ifdef SAIF_ON
initial begin
	$set_toggle_region("top.u_reshaper");
	$toggle_start();
end
final begin
	$toggle_stop();
	$toggle_report("reshaper.saif", 1e-9, "top.u_reshaper");
end
`endif

`ifdef RTL_SIM
reshaper #(.AW(top.AW), .DW(top.DW), .BUFFW(top.BUFFW), .ADIM(top.ADIM), .MEM_DELAY(top.MEM_DELAY)) u_reshaper(.*);
bind top.u_reshaper reshaper_assertion #(.AW(top.AW)) u_reshaper_assertion(.*);
bind top.u_reshaper.u_raddr_gen nested_addr_gen_assertion #(.DEPTH(top.ADIM), .AW(top.AW)) u_raddr_gen_assertion(.*);
bind top.u_reshaper.u_waddr_gen nested_addr_gen_assertion #(.DEPTH(top.ADIM), .AW(top.AW)) u_waddr_gen_assertion(.*);
bind top.u_reshaper.u_rd_fifo fifo_assertion #(.DW(top.DW + $clog2(top.DW / 8) + 1)) u_rdfifo_assertion(.*);
bind top.u_reshaper reshaper_coverage #(.AW(top.AW), .DW(top.DW)) u_reshaper_coverage(.*);
`endif
`ifdef PRE_SIM
reshaper u_reshaper(
    .clk(clk)
,   .reset_n(reset_n)
,   .init_pulse(init_pulse)
,   .rreq_num(rreq_num)
,   .raddr_base(raddr_base)
,   .raddr_size({>>AW{raddr_size}})
,   .raddr_stride({>>AW{raddr_stride}})
,   .wreq_num(wreq_num)
,   .waddr_base(waddr_base)
,   .waddr_size({>>AW{waddr_size}})
,   .waddr_stride({>>AW{waddr_stride}})
,   .rdata_size(rdata_size)
,   .wdata_size(wdata_size)
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