module reshaper #(parameter AW=16, DW=512, BUFFW=512*3, ADIM=6, MEM_DELAY=8)(
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
localparam DBYTE = DW / 8;
localparam RDFFD = MEM_DELAY + 7;

reg run;

wire raddr_req;
wire [AW-1:0] raddr_bpad[ADIM];
wire [AW-1:0] raddr_apad[ADIM];
wire inc_rreqcnt;
wire clr_rreqcnt;
reg [AW-1:0] rreqcnt;
reg [AW-1:0] rreqcnt_max;
reg [$clog2(RDFFD):0] pend_rreqcnt;

wire inc_rbytecnt;
wire clr_rbytecnt;
reg [AW-1:0] rbytecnt;
reg [AW-1:0] rbytecnt_max;
wire [$clog2(DBYTE):0] rbyte;
reg [$clog2(DBYTE):0] last_rbyte;

typedef struct packed {
    logic [$clog2(DBYTE):0] rbyte;
    logic [DBYTE-1:0][7:0] rdata;
} rdata_t;
reg rdffwreq;
rdata_t rdffwdata;
wire rdffrreq;
rdata_t rdffrdata;
wire rdffrvld;

wire rshpffwreq;
wire [$clog2(DBYTE):0] rshpffwbyte;
wire [DW-1:0] rshpffwdata;
wire rshpffrreq;
wire [$clog2(DBYTE):0] rshpffrbyte;
reg [DW-1:0] rshpffrdata;
reg [DW-1:0] rshpffrdata_d[2];
reg rshpffrvld;
reg [$clog2(BUFFW/8):0] rshpffvbyte;

wire inc_wbytecnt;
wire clr_wbytecnt;
reg [AW-1:0] wbytecnt;
reg [AW-1:0] wbytecnt_max;
wire [$clog2(DBYTE):0] wbyte;
reg [$clog2(DBYTE):0] last_wbyte;

wire waddr_req;
wire [AW-1:0] waddr_bpad[ADIM];
wire [AW-1:0] waddr_apad[ADIM];

wire inc_wreqcnt;
wire clr_wreqcnt;
reg [AW-1:0] wreqcnt;
reg [AW-1:0] wreqcnt_max;
reg lastwreq;
reg lastwreq_d[2];


always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)        run <= 0;
    else if(init_pulse) run <= 1;
    else if(finish)     run <= 0;
end

assign raddr_req = (pend_rreqcnt < RDFFD) & (rreqcnt != rreqcnt_max) & run;
for(genvar i=0; i<ADIM; i++) assign raddr_bpad[i] = 0;
for(genvar i=0; i<ADIM; i++) assign raddr_apad[i] = 0;
assign inc_rreqcnt = raddr_req;
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
    else if(raddr_req & ~rdffrreq) pend_rreqcnt <= pend_rreqcnt + 1;
    else if(~raddr_req & rdffrreq) pend_rreqcnt <= pend_rreqcnt - 1;
end
nested_addr_gen#(.DEPTH(ADIM), .AW(AW)) u_raddr_gen(
    .clk
,   .reset_n
,   .init_pulse
,   .addr_req(raddr_req)
,   .base(raddr_base)
,   .pad_before(raddr_bpad)
,   .size(raddr_size)
,   .pad_after(raddr_apad)
,   .stride(raddr_stride)
,   .addr(raddr)
,   .addr_vld(raddr_vld)
,   .pad_vld()
);

assign inc_rbytecnt = rdata_vld;
assign clr_rbytecnt = rdata_vld & (rbytecnt == (rbytecnt_max - 1));
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)          rbytecnt <= 0;
    else if(init_pulse)   rbytecnt <= 0;
    else if(clr_rbytecnt) rbytecnt <= 0;
    else if(inc_rbytecnt) rbytecnt <= rbytecnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        rbytecnt_max <= 0;
    else if(init_pulse) rbytecnt_max <= rdata_size[AW-1:$clog2(DBYTE)] + (|rdata_size[$clog2(DBYTE)-1:0]);
end
assign rbyte = (rbytecnt == (rbytecnt_max - 1)) ? last_rbyte : DBYTE;
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        last_rbyte <= 0;
    else if(init_pulse) last_rbyte <= (|rdata_size[$clog2(DBYTE)-1:0]) ? rdata_size[$clog2(DBYTE)-1:0] : DBYTE;
end

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)        rdffwreq <= 0;
    else if(init_pulse) rdffwreq <= 0;
    else if(rdata_vld)  rdffwreq <= 1;
    else                rdffwreq <= 0;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         rdffwdata.rbyte <= 0;
    else if(init_pulse)  rdffwdata.rbyte <= 0;
    else if(rdata_vld)   rdffwdata.rbyte <= rbyte;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         rdffwdata.rdata <= 0;
    else if(init_pulse)  rdffwdata.rdata <= 0;
    else if(rdata_vld)   rdffwdata.rdata <= rdata;
end
assign rdffrreq = rshpffwreq;
fwft_fifo#(.FD(RDFFD), .DW($bits(rdata_t))) u_rd_fifo(
    .clk
,   .reset_n
,   .ffwfull()
,   .ffwreq(rdffwreq)
,   .ffwdata(rdffwdata)
,   .ffrempty()
,   .ffrreq(rdffrreq)
,   .ffrdata(rdffrdata)
,   .ffrvld(rdffrvld)
,   .ffvcnt()
);

assign rshpffwreq = rdffrvld & (rshpffvbyte <= (BUFFW/8) - DBYTE);
assign rshpffwbyte = rdffrdata.rbyte;
assign rshpffwdata = rdffrdata.rdata;
assign rshpffrreq = (rshpffrbyte <= rshpffvbyte) & run;
assign rshpffrbyte = wbyte;
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)          rshpffrdata_d[0] <= 0;
    else if(init_pulse)   rshpffrdata_d[0] <= 0;
    else                  rshpffrdata_d[0] <= rshpffrdata;
end
for(genvar i=1; i<$size(rshpffrdata_d); i++) begin
    always_ff@(posedge clk or negedge reset_n) begin
        if(~reset_n)          rshpffrdata_d[i] <= 0;
        else if(init_pulse)   rshpffrdata_d[i] <= 0;
        else                  rshpffrdata_d[i] <= rshpffrdata_d[i-1];
    end
end
rshp_fifo #(.DW(DW), .BUFFW(BUFFW)) u_rshp_fifo(
    .clk
,   .reset_n
,   .init_pulse
,   .ffwreq(rshpffwreq)
,   .ffwbyte(rshpffwbyte)
,   .ffwdata(rshpffwdata)
,   .ffrreq(rshpffrreq)
,   .ffrbyte(rshpffrbyte)
,   .ffrdata(rshpffrdata)
,   .ffrvld(rshpffrvld)
,   .ffvbyte(rshpffvbyte)
);

assign inc_wbytecnt = rshpffrreq;
assign clr_wbytecnt = rshpffrreq & (wbytecnt == (wbytecnt_max - 1));
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)          wbytecnt <= 0;
    else if(init_pulse)   wbytecnt <= 0;
    else if(clr_wbytecnt) wbytecnt <= 0;
    else if(inc_wbytecnt) wbytecnt <= wbytecnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        wbytecnt_max <= 0;
    else if(init_pulse) wbytecnt_max <= wdata_size[AW-1:$clog2(DBYTE)] + (|wdata_size[$clog2(DBYTE)-1:0]);
end
assign wbyte = (wbytecnt == (wbytecnt_max - 1)) ? last_wbyte : DBYTE;
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        last_wbyte <= 0;
    else if(init_pulse) last_wbyte <= (|wdata_size[$clog2(DBYTE)-1:0]) ? wdata_size[$clog2(DBYTE)-1:0] : DBYTE;
end

assign waddr_req = rshpffrvld & (wreqcnt < wreqcnt_max) & run;
for(genvar i=0; i<ADIM; i++) assign waddr_bpad[i] = 0;
for(genvar i=0; i<ADIM; i++) assign waddr_apad[i] = 0;
nested_addr_gen#(.DEPTH(ADIM), .AW(AW)) u_waddr_gen(
    .clk
,   .reset_n
,   .init_pulse
,   .addr_req(waddr_req)
,   .base(waddr_base)
,   .pad_before(waddr_bpad)
,   .size(waddr_size)
,   .pad_after(waddr_apad)
,   .stride(waddr_stride)
,   .addr(waddr)
,   .addr_vld(wdata_vld)
,   .pad_vld()
);

assign inc_wreqcnt = waddr_req & (wreqcnt < wreqcnt_max);
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
    if(~reset_n)                                        lastwreq <= 0;
    else if(init_pulse)                                 lastwreq <= 0;
    else if(waddr_req & (wreqcnt == (wreqcnt_max - 1))) lastwreq <= 1;
    else                                                lastwreq <= 0;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)          lastwreq_d[0] <= 0;
    else if(init_pulse)   lastwreq_d[0] <= 0;
    else                  lastwreq_d[0] <= lastwreq;
end
for(genvar i=1; i<$size(lastwreq_d); i++) begin
    always_ff@(posedge clk or negedge reset_n) begin
        if(~reset_n)          lastwreq_d[i] <= 0;
        else if(init_pulse)   lastwreq_d[i] <= 0;
        else                  lastwreq_d[i] <= lastwreq_d[i-1];
    end
end

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         wdata <= 0;
    else if(init_pulse)  wdata <= wreq_num;
    else                 wdata <= rshpffrdata_d[$size(rshpffrdata_d)-1];
end

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)                             finish <= 0;
    else if(init_pulse)                      finish <= 0;
    else if(lastwreq_d[$size(lastwreq_d)-1]) finish <= 1;
    else                                     finish <= 0;
end

endmodule: reshaper