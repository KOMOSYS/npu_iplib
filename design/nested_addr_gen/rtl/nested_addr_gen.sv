module nested_addr_gen #(parameter DEPTH=4, AW=32) (
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
wire             cnt_enable[DEPTH];
reg  [AW-1:0]    cnt_max[DEPTH];
reg  [AW-1:0]    cnt_stride[DEPTH];
reg  [AW-1:0]    ctrl_cnt[DEPTH];
reg  [AW-1:0]    addr_cnt[DEPTH];
wire             inc_ctrl_cnt[DEPTH];
wire             inc_addr_cnt[DEPTH];
wire             clr_cnt[DEPTH];
reg  [AW-1:0]    base_addr;
reg  [AW-1:0]    cur_addr;
reg  [DEPTH-1:0] ispad;

/** If size is 0 set cnt_enable 0 */
for(genvar i=0; i<DEPTH; i++) begin
	assign cnt_enable[i] = size[i] != 0;
end

/** Set address counter stride and max */
for(genvar i=0; i<DEPTH; i++) begin
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)                        cnt_max[i] <= 0;
		else if(init_pulse & cnt_enable[i]) cnt_max[i] <= pad_before[i] + size[i] + pad_after[i];
	end
end
for(genvar i=0; i<DEPTH; i++) begin
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)        cnt_stride[i] <= 0;
		else if(init_pulse) cnt_stride[i] <= stride[i];
	end
end

/** Increase or clear address counter */
for(genvar i=0; i<DEPTH; i++) begin
	if(i == 0) assign clr_cnt[0] = cnt_enable[0] & (ctrl_cnt[0] == (cnt_max[0] - 1)) & addr_req;
	else       assign clr_cnt[i] = cnt_enable[i] & (ctrl_cnt[i] == (cnt_max[i] - 1)) & clr_cnt[i-1];
end
for(genvar i=0; i<DEPTH; i++) begin
	if(i == 0) assign inc_ctrl_cnt[0] = cnt_enable[0] & addr_req;
	else       assign inc_ctrl_cnt[i] = cnt_enable[i] & clr_cnt[i-1];
end
for(genvar i=0; i<DEPTH; i++) begin
	assign inc_addr_cnt[i] = inc_ctrl_cnt[i] & (ctrl_cnt[i] >= pad_before[i]) & (ctrl_cnt[i] < pad_before[i] + size[i] - 1);
end
for(genvar i=0; i<DEPTH; i++) begin
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)             ctrl_cnt[i] <= 0;
		else if(init_pulse)      ctrl_cnt[i] <= 0;
		else if(clr_cnt[i])      ctrl_cnt[i] <= 0;
		else if(inc_ctrl_cnt[i]) ctrl_cnt[i] <= ctrl_cnt[i] + 1;
	end
end
for(genvar i=0; i<DEPTH; i++) begin
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)             addr_cnt[i] <= 0;
		else if(init_pulse)      addr_cnt[i] <= 0;
		else if(clr_cnt[i])      addr_cnt[i] <= 0;
		else if(inc_addr_cnt[i]) addr_cnt[i] <= addr_cnt[i] + cnt_stride[i];
	end
end

/** Get output address from address counter */
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)        base_addr <= 0;
	else if(init_pulse) base_addr <= base;
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)      addr_vld <= 0;
	else if(addr_req) addr_vld <= 1;
	else              addr_vld <= 0;
end
always_comb begin
	cur_addr = 0;
	for(int i=0; i<DEPTH; i++)
		cur_addr = cur_addr + addr_cnt[i];
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)      addr <= 0;
	else if(addr_req) addr <= base_addr + cur_addr;
end
for(genvar i=0; i<DEPTH; i++) begin
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)      ispad[i] <= 0;
		else if(addr_req) ispad[i] <= cnt_enable[i] & ((ctrl_cnt[i] < pad_before[i]) | (ctrl_cnt[i] >= pad_before[i] + size[i]));
	end
end

assign pad_vld = |ispad;

endmodule: nested_addr_gen
