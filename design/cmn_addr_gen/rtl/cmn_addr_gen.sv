/*
Function of DEPTH 2 cmn_addr_gen:
for(int j=0; j<(addr_size[1]+1); j++) {
	for(int i=0; i<(addr_size[0]+1); i++) {
		addr = addr_base = i*addr_stride[0] + j*addr_stride[1];
	}
}
*/

module cmn_addr_gen #(parameter DEPTH=5, AW=16) (
	input               clk,
	input               reset_n,
	input               init_pulse,
	input               addr_req,
	input  [AW-1:0]     addr_base,
	input  [AW-1:0]     addr_size[DEPTH],
	input  [AW-1:0]     addr_stride[DEPTH],
	output reg [AW-1:0] addr,
	output reg          addr_valid
);

reg  [AW-1:0] cnt_max[DEPTH];
reg  [AW-1:0] cnt_stride[DEPTH];
reg  [AW-1:0] ctrl_cnt[DEPTH];
reg  [AW-1:0] addr_cnt[DEPTH];
wire          inc_cnt[DEPTH];
wire          clr_cnt[DEPTH];
reg  [AW-1:0] cur_addr;

/** Set address counter stride and max */
for(genvar i=0; i<DEPTH; i++) begin
	always_ff @(posedge clk or negedge reset_n) begin
		if(!reset_n)        cnt_max[i] <= 0;
		else if(init_pulse) cnt_max[i] <= addr_size[i];
	end
end
for(genvar i=0; i<DEPTH; i++) begin
	always_ff @(posedge clk or negedge reset_n) begin
		if(!reset_n)        cnt_stride[i] <= 0;
		else if(init_pulse) cnt_stride[i] <= addr_stride[i];
	end
end

/** Increase or clear address counter */
for(genvar i=0; i<DEPTH; i++) begin
	assign clr_cnt[i] = ctrl_cnt[i] == cnt_max[i];
end
assign inc_cnt[0] = addr_req;
for(genvar i=1; i<DEPTH; i++) begin
	assign inc_cnt[i] = clr_cnt[i-1];
end
for(genvar i=0; i<DEPTH; i++) begin
	always_ff @(posedge clk or negedge reset_n) begin
		if(!reset_n)        ctrl_cnt[i] <= 0;
		else if(init_pulse) ctrl_cnt[i] <= 0;
		else if(clr_cnt[i]) ctrl_cnt[i] <= 0;
		else if(inc_cnt[i]) ctrl_cnt[i] <= ctrl_cnt[i] + 1;
	end
end
for(genvar i=0; i<DEPTH; i++) begin
	always_ff @(posedge clk or negedge reset_n) begin
		if(!reset_n)        addr_cnt[i] <= 0;
		else if(init_pulse) addr_cnt[i] <= 0;
		else if(clr_cnt[i]) addr_cnt[i] <= 0;
		else if(inc_cnt[i]) addr_cnt[i] <= addr_cnt[i] + cnt_stride[i];
	end
end

/** Get output address from address counter */
always_ff @(posedge clk or negedge reset_n) begin
	if(!reset_n)      addr_valid <= 0;
	else if(addr_req) addr_valid <= 1;
	else              addr_valid <= 0;
end
always_comb begin
	cur_addr = addr_base;
	for(int i=0; i<DEPTH; i++)
		cur_addr = cur_addr + addr_cnt[i];
end
always_ff @(posedge clk or negedge reset_n) begin
	if(!reset_n)      addr <= 0;
	else if(addr_req) addr <= cur_addr;
end

endmodule: cmn_addr_gen
