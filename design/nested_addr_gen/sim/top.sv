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

`ifdef SAIF_ON
initial begin
	$set_toggle_region("top.u_nested_addr_gen");
	$toggle_start();
end
final begin
	$toggle_stop();
	$toggle_report("nested_addr_gen.saif", 1e-9, "top.u_nested_addr_gen");
end
`endif

`ifdef RTL_SIM
nested_addr_gen #(.DEPTH(top.DEPTH), .AW(top.AW)) u_nested_addr_gen(.*);
bind top.u_nested_addr_gen nested_addr_gen_assertion #(.AW(top.AW), .DEPTH(top.DEPTH)) u_nested_addr_gen_assertion(.*);
bind top.u_nested_addr_gen nested_addr_gen_coverage #(.AW(top.AW), .DEPTH(top.DEPTH)) u_nested_addr_gen_coverage(.*);
`endif
`ifdef PRE_SIM
nested_addr_gen u_nested_addr_gen(
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
`endif
endmodule: top