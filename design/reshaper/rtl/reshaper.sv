module reshaper #(parameter AW=16, DW=512, ADIM=6)(
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
parameter MEM_DELAY = 8;
parameter RDFFD = MEM_DELAY + 3;

wire inc_rreqcnt;
wire clr_rreqcnt;
reg [AW-1:0] rreqcnt;
reg [AW-1:0] rreqcnt_max;
reg [AW-1:0] pend_rreqcnt;

wire raddr_req;

wire rdffrreq;
wire [DW-1:0] rdffrdata;
wire [$clog2(RDFFD):0] rdffvcnt;
wire rdffrempty;

wire inc_rbytecnt;
wire clr_rbytecnt;
reg [AW-1:0] rbytecnt;
reg [AW-1:0] rbytecnt_max;

wire inc_wbytecnt;
wire clr_wbytecnt;
reg [AW-1:0] wbytecnt;
reg [AW-1:0] wbytecnt_max;

wire rshpffwreq;
wire [$clog2(DW/8):0] rshpffwbyte;
wire [DW-1:0] rshpffwdata;
reg rshpffwdata_vld;
wire rshpffrreq;
wire [$clog2(DW/8):0] rshpffrbyte;
reg [DW-1:0] rshpffrdata;
reg rshpffrvld;
wire [$clog2(DW/8*2):0] rshpffvbyte;
wire rshpffwfull;
wire rshpffrempty;

wire inc_wreqcnt;
wire clr_wreqcnt;
reg [AW-1:0] wreqcnt;
reg [AW-1:0] wreqcnt_max;

assign inc_rreqcnt = raddr_req & (rreqcnt < rreqcnt_max);
assign clr_rreqcnt = finish;
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         rreqcnt <= 0;
    else if(init_pulse)  rreqcnt <= 0;
    else if(clr_rreqcnt) rreqcnt <= 0;
    else if(inc_rreqcnt) rreqcnt <= rreqcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         rreqcnt_max <= 0;
    else if(init_pulse)  rreqcnt_max <= rreq_num;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)                   pend_rreqcnt <= 0;
    else if(init_pulse)            pend_rreqcnt <= 0;
    else if(raddr_req & rdata_vld) pend_rreqcnt <= pend_rreqcnt;
    else if(raddr_req)             pend_rreqcnt <= pend_rreqcnt + 1;
    else if(rdata_vld)             pend_rreqcnt <= pend_rreqcnt - 1;
end

assign raddr_req = ((rdffvcnt + pend_rreqcnt) < RDFFD) & (rreqcnt < rreqcnt_max);
nested_addr_gen#(.DEPTH(ADIM), .AW(AW)) raddr_gen(
    .clk
,   .reset_n
,   .init_pulse
,   .addr_req(raddr_req)
,   .base(raddr_base)
,   .pad_before('{ADIM{0}})
,   .size(raddr_size)
,   .pad_after('{ADIM{0}})
,   .stride(raddr_stride)
,   .addr(raddr)
,   .addr_vld(raddr_vld)
,   .pad_vld()
);

assign rdffrreq = (~rshpffwdata_vld | rshpffwreq) & ~rdffrempty;
fifo#(.FD(RDFFD), .DW(DW)) rd_fifo(
    .clk
,   .reset_n
,   .ffwreq(rdata_vld)
,   .ffwdata(rdata)
,   .ffrreq(rdffrreq)
,   .ffrdata(rdffrdata)
,   .ffrvld()
,   .ffvcnt(rdffvcnt)
,   .ffwfull()
,   .ffrempty(rdffrempty)
);

assign inc_rbytecnt = rshpffwreq;
assign clr_rbytecnt = rshpffwreq & ((rbytecnt + (DW/8)) >= rbytecnt_max);
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)          rbytecnt <= 0;
    else if(init_pulse)   rbytecnt <= 0;
    else if(clr_rbytecnt) rbytecnt <= 0;
    else if(inc_rbytecnt) rbytecnt <= rbytecnt + (DW/8);
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        rbytecnt_max <= 0;
    else if(init_pulse) rbytecnt_max <= rdata_size;
end

assign inc_wbytecnt = rshpffrreq;
assign clr_wbytecnt = rshpffrreq & ((wbytecnt + (DW/8)) >= wbytecnt_max);
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)          wbytecnt <= 0;
    else if(init_pulse)   wbytecnt <= 0;
    else if(clr_wbytecnt) wbytecnt <= 0;
    else if(inc_wbytecnt) wbytecnt <= wbytecnt + (DW/8);
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        wbytecnt_max <= 0;
    else if(init_pulse) wbytecnt_max <= wdata_size;
end

assign rshpffwreq = rshpffwdata_vld & ~rshpffwfull;
assign rshpffwbyte = ((rbytecnt_max - rbytecnt) > (DW/8)) ? (DW/8) : (rbytecnt_max - rbytecnt);
assign rshpffwdata = rshpffwdata_vld ? rdffrdata : rshpffwdata;
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                           rshpffwdata_vld <= 0;
    else if(init_pulse)                    rshpffwdata_vld <= 0;
    else if(rdffrreq)                      rshpffwdata_vld <= 1;
    else if(~rshpffwreq & rshpffwdata_vld) rshpffwdata_vld <= 1;
    else                                   rshpffwdata_vld <= 0;
end
assign rshpffrreq = ~rshpffrempty & (rshpffvbyte >= rshpffrbyte);
assign rshpffrbyte = ((wbytecnt_max - wbytecnt) > (DW/8)) ? (DW/8) : (wbytecnt_max - wbytecnt);

rshp_fifo #(.DW(DW)) u_rshp_fifo(
    .clk
,   .reset_n
,   .ffwreq(rshpffwreq)
,   .ffwbyte(rshpffwbyte)
,   .ffwdata(rshpffwdata)
,   .ffrreq(rshpffrreq)
,   .ffrbyte(rshpffrbyte)
,   .ffrdata(rshpffrdata)
,   .ffrvld(rshpffrvld)
,   .ffvbyte(rshpffvbyte)
,   .ffwfull(rshpffwfull)
,   .ffrempty(rshpffrempty)
);

assign waddr_req = rshpffrreq;
nested_addr_gen#(.DEPTH(ADIM), .AW(AW)) waddr_gen(
    .clk
,   .reset_n
,   .init_pulse
,   .addr_req(waddr_req)
,   .base(waddr_base)
,   .pad_before('{ADIM{0}})
,   .size(waddr_size)
,   .pad_after('{ADIM{0}})
,   .stride(waddr_stride)
,   .addr(waddr)
,   .addr_vld() //TODO check with data valid assertion
,   .pad_vld()
);

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        wdata <= 0;
    else if(init_pulse) wdata <= 0;
    else if(rshpffrvld) wdata <= rshpffrdata;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        wdata_vld <= 0;
    else if(init_pulse) wdata_vld <= 0;
    else if(rshpffrvld) wdata_vld <= 1;
    else                wdata_vld <= 0;
end

assign inc_wreqcnt = wdata_vld & (wreqcnt < wreqcnt_max);
assign clr_wreqcnt = finish;
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)         wreqcnt <= 0;
    else if(init_pulse)  wreqcnt <= 0;
    else if(clr_wreqcnt) wreqcnt <= 0;
    else if(inc_wreqcnt) wreqcnt <= wreqcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         wreqcnt_max <= 0;
    else if(init_pulse)  wreqcnt_max <= wreq_num;
end

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)                                                 finish <= 0;
    else if((rreqcnt == rreqcnt_max) & (wreqcnt == wreqcnt_max)) finish <= 1;
    else                                                         finish <= 0;
end

endmodule: reshaper