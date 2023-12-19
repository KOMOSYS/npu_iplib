module nested_addr_gen #(parameter DEPTH=5, AW=8) (
	input               clk,
	input               reset_n,
	input               init_pulse,
	input               addr_req,
	input      [AW-1:0] base,
	input      [AW-1:0] size[DEPTH],
	input      [AW-1:0] stride[DEPTH],
	output reg [AW-1:0] addr,
	output reg          addr_vld
);

reg  [AW-1:0] cnt_max[DEPTH];
reg  [AW-1:0] cnt_stride[DEPTH];
reg  [AW-1:0] ctrl_cnt[DEPTH];
reg  [AW-1:0] addr_cnt[DEPTH];
wire          inc_cnt[DEPTH];
wire          clr_cnt[DEPTH];
reg  [AW-1:0] base_addr;
reg  [AW-1:0] cur_addr;

/** Set address counter stride and max */
for(genvar i=0; i<DEPTH; i++) begin
	always_ff @(posedge clk or negedge reset_n) begin
		if(!reset_n)        cnt_max[i] <= 0;
		else if(init_pulse) cnt_max[i] <= size[i] - 1;
	end
end
for(genvar i=0; i<DEPTH; i++) begin
	always_ff @(posedge clk or negedge reset_n) begin
		if(!reset_n)        cnt_stride[i] <= 0;
		else if(init_pulse) cnt_stride[i] <= stride[i];
	end
end
always_ff @(posedge clk or negedge reset_n) begin
	if(!reset_n)        base_addr <= 0;
	else if(init_pulse) base_addr <= base;
end

/** Increase or clear address counter */
for(genvar i=0; i<DEPTH; i++) begin
	if(i == 0) assign clr_cnt[0] = ctrl_cnt[0] == cnt_max[0];
	else       assign clr_cnt[i] = (ctrl_cnt[i] == cnt_max[i]) & clr_cnt[i-1];
end
for(genvar i=0; i<DEPTH; i++) begin
	if(i == 0) assign inc_cnt[0] = addr_req;
	else       assign inc_cnt[i] = clr_cnt[i-1];
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
	if(!reset_n)      addr_vld <= 0;
	else if(addr_req) addr_vld <= 1;
	else              addr_vld <= 0;
end
always_comb begin
	cur_addr = base_addr;
	for(int i=0; i<DEPTH; i++)
		cur_addr = cur_addr + addr_cnt[i];
end
always_ff @(posedge clk or negedge reset_n) begin
	if(!reset_n)      addr <= 0;
	else if(addr_req) addr <= cur_addr;
end

endmodule: nested_addr_gen
