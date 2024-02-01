module top #(parameter DEPTH=6, AW=16) (
	input               clk,
	input               reset_n,
	input               init_pulse,
	input               addr_req,
	input      [AW-1:0] base,
	input      [AW-1:0] pad_before[DEPTH],
	input      [AW-1:0] size[DEPTH],
	input      [AW-1:0] pad_after[DEPTH],
	input      [AW-1:0] stride[DEPTH],
	output reg [AW-1:0] addr,
	output reg          addr_vld,
	output reg          pad_vld
);

nested_addr_gen #(.DEPTH(DEPTH), .AW(AW)) u_nested_addr_gen(
	.clk(clk)
,	.reset_n(reset_n)
,	.init_pulse(init_pulse)
,	.addr_req(addr_req)
,	.base(base)
,	.pad_before({>>AW{pad_before}})
,	.size({>>AW{size}})
,	.pad_after({>>AW{pad_after}})
,	.stride({>>AW{stride}})
,	.addr(addr)
,	.addr_vld(addr_vld)
,	.pad_vld(pad_vld)
);
`ifdef RTL_SIM
bind top.u_nested_addr_gen nested_addr_gen_assertion #(.AW(AW), .DEPTH(DEPTH)) u_nested_addr_gen_assertion(
	.clk(clk)
,	.reset_n(reset_n)
,	.init_pulse(init_pulse)
,	.size(size)
,	.addr(addr)
,	.addr_vld(addr_vld)
);
bind top.u_nested_addr_gen nested_addr_gen_coverage #(.AW(AW), .DEPTH(DEPTH)) u_nested_addr_gen_coverage(
	.reset_n(reset_n)
,	.init_pulse(init_pulse)
,	.base(base)
,	.pad_before(pad_before)
,	.size(size)
,	.pad_after(pad_after)
);
`endif
endmodule: top