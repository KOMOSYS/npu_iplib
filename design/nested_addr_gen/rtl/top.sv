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

nested_addr_gen #(.DEPTH(DEPTH), .AW(AW)) u_nested_addr_gen(.*);
bind top.u_nested_addr_gen nested_addr_gen_assertion #(.AW(AW), .DEPTH(DEPTH)) u_nested_addr_gen_assertion(.*);
bind top.u_nested_addr_gen nested_addr_gen_coverage #(.AW(AW), .DEPTH(DEPTH)) u_nested_addr_gen_coverage(.*);

endmodule: top