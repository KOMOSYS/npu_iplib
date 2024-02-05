module nested_addr_gen #(parameter DEPTH=6, AW=16) (
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

reg  [AW-1:0]    pad_before_max[DEPTH];
reg  [AW-1:0]    size_max[DEPTH];
reg  [AW-1:0]    pad_before_size_max[DEPTH];
reg  [AW-1:0]    ctrl_cnt_max[DEPTH];
reg  [AW-1:0]    addr_stride[DEPTH];
reg  [AW-1:0]    base_addr;

wire [DEPTH-1:0] cnt_ismax;
wire             clr_ctrl_cnt[DEPTH];
wire             inc_ctrl_cnt[DEPTH];
reg  [AW-1:0]    ctrl_cnt[DEPTH];

reg              clr_addr_cnt[DEPTH];
reg              inc_addr_cnt[DEPTH];
reg  [AW-1:0]    addr_cnt[DEPTH];
reg  [DEPTH-1:0] is_pad;

reg  [AW-1:0]    addr_sum[DEPTH/2];
reg              pad_vld_tmp;

reg  [1:0]       addr_req_d;
reg  [AW-1:0]    cur_addr;

for(genvar i=0; i<DEPTH; i++) begin
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)        pad_before_max[i] <= 0;
		else if(init_pulse) pad_before_max[i] <= pad_before[i];
	end
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)        size_max[i] <= 0;
		else if(init_pulse) size_max[i] <= size[i];
	end
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)        pad_before_size_max[i] <= 0;
		else if(init_pulse) pad_before_size_max[i] <= pad_before[i] + size[i];
	end
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)        ctrl_cnt_max[i] <= 0;
		else if(init_pulse) ctrl_cnt_max[i] <= pad_before[i] + size[i] + pad_after[i];
	end
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)        addr_stride[i] <= 0;
		else if(init_pulse) addr_stride[i] <= stride[i];
	end
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)        base_addr <= 0;
	else if(init_pulse) base_addr <= base;
end

for(genvar i=0; i<DEPTH; i++) begin
	assign cnt_ismax[i] = ctrl_cnt[i] == (ctrl_cnt_max[i] - 1);
	assign clr_ctrl_cnt[i] = addr_req & (&cnt_ismax[i:0]);
	if(i == 0) assign inc_ctrl_cnt[0] = addr_req;
	else       assign inc_ctrl_cnt[i] = addr_req & clr_ctrl_cnt[i-1];

	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)             ctrl_cnt[i] <= 0;
		else if(init_pulse)      ctrl_cnt[i] <= 0;
		else if(clr_ctrl_cnt[i]) ctrl_cnt[i] <= 0;
		else if(inc_ctrl_cnt[i]) ctrl_cnt[i] <= ctrl_cnt[i] + 1;
	end
end

for(genvar i=0; i<DEPTH; i++) begin
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)             clr_addr_cnt[i] <= 0;
		else if(init_pulse)      clr_addr_cnt[i] <= 0;
		else if(clr_ctrl_cnt[i]) clr_addr_cnt[i] <= 1;
		else                     clr_addr_cnt[i] <= 0;
	end
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)                                                                             inc_addr_cnt[i] <= 0;
		else if(init_pulse)                                                                      inc_addr_cnt[i] <= 0;
		else if(!inc_ctrl_cnt[i])                                                                inc_addr_cnt[i] <= 0;
		else if((ctrl_cnt[i] >= pad_before_max[i]) & (ctrl_cnt[i] < pad_before_size_max[i] - 1)) inc_addr_cnt[i] <= 1;
		else                                                                                     inc_addr_cnt[i] <= 0;  
	end
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)             addr_cnt[i] <= 0;
		else if(init_pulse)      addr_cnt[i] <= 0;
		else if(clr_addr_cnt[i]) addr_cnt[i] <= 0;
		else if(inc_addr_cnt[i]) addr_cnt[i] <= addr_cnt[i] + addr_stride[i];
	end
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)                                                                         is_pad[i] <= 0;
		else if(init_pulse)                                                                  is_pad[i] <= 0;
		else if((ctrl_cnt[i] < pad_before_max[i]) | (ctrl_cnt[i] >= pad_before_size_max[i])) is_pad[i] <= 1;
		else                                                                                 is_pad[i] <= 0;
	end
end

for(genvar i=0; i<(DEPTH/2); i++) begin
	always_ff@(posedge clk or negedge reset_n) begin
		if(~reset_n)         addr_sum[i] <= 0;
		else if(init_pulse)  addr_sum[i] <= 0;
		else                 addr_sum[i] <= addr_cnt[2*i] + addr_cnt[2*i+1];
	end
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)         pad_vld_tmp <= 0;
	else if(init_pulse)  pad_vld_tmp <= 0;
	else                 pad_vld_tmp <= |is_pad;
end

always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)         addr_req_d <= 0;
	else if(init_pulse)  addr_req_d <= 0;
	else                 addr_req_d <= {addr_req_d[$size(addr_req_d)-2:0], addr_req};
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)        addr_vld <= 0;
	else if(init_pulse) addr_vld <= 0;
	else                addr_vld <= addr_req_d[$size(addr_req_d)-1];
end
always_comb begin
	cur_addr = 0;
	for(int i=0; i<(DEPTH/2); i++)
		cur_addr = cur_addr + addr_sum[i];
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)        addr <= 0;
	else if(init_pulse) addr <= 0;
	else                addr <= base_addr + cur_addr;
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)        pad_vld <= 0;
	else if(init_pulse) pad_vld <= 0;
	else                pad_vld <= pad_vld_tmp;
end
endmodule: nested_addr_gen
