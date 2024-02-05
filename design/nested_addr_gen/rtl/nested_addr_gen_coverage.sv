module nested_addr_gen_coverage #(parameter DEPTH=4, AW=32) (
	input          reset_n,
	input          init_pulse,
	input [AW-1:0] base,
	input logic [AW-1:0] pad_before[DEPTH],
	input [AW-1:0] size[DEPTH],
	input logic [AW-1:0] pad_after[DEPTH]
);

covergroup cg_addr @(posedge init_pulse iff (reset_n));
	cp_base_nonzero : coverpoint base {
		bins nonzero = {[0:$]} with (item != 0); 
	}
endgroup: cg_addr

covergroup cg_pad(ref logic [AW-1:0] bpad, apad) @(posedge init_pulse iff (reset_n));
	cp_pad_before : coverpoint bpad {
		bins zero = {0};
		bins nonzero = {[0:$]} with (item != 0);
	}
	cp_pad_after : coverpoint apad {
		bins zero = {0};
		bins nonzero = {[0:$]} with (item != 0);
	}
	cx_pad_comb : cross cp_pad_before, cp_pad_after;
endgroup: cg_pad

cg_addr u_cg_addr = new();
cg_pad u_cg_pad[DEPTH];
for(genvar i=0; i<DEPTH; i++)
	initial u_cg_pad[i] = new(pad_before[i], pad_after[i]);

endmodule: nested_addr_gen_coverage
