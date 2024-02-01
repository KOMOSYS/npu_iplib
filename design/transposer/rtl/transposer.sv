module transposer #(parameter AW=16, BUFFD=64, ADIM=6, MEM_DELAY=8)(
    input clk,
    input reset_n,
    input init_pulse,
    input repack_en,
    input [1:0] mode,

    input [AW-1:0] rreq_num,
    input [AW-1:0] raddr_base,
    input [AW-1:0] raddr_size[ADIM],
    input [AW-1:0] raddr_stride[ADIM],
    input [AW-1:0] wreq_num,
    input [AW-1:0] waddr_base,
    input [AW-1:0] waddr_size[ADIM],
    input [AW-1:0] waddr_stride[ADIM],

    input [AW-1:0] packed_dim_size,
    input [AW-1:0] unpacked_dim_size,

    output reg [AW-1:0] raddr,
    output reg raddr_vld,
    input [BUFFD*8-1:0] rdata,
    input rdata_vld,
    output reg [AW-1:0] waddr,
    output reg [BUFFD*8-1:0] wdata,
    output reg wdata_vld,
    output reg finish
);
localparam RDFFD = MEM_DELAY + 6;

typedef enum logic [1:0] {
    BIT8_MODE  = 2'b01,
    BIT32_MODE = 2'b10
} mode_t;

reg run;

wire raddr_req;
wire [AW-1:0] raddr_bpad[ADIM];
wire [AW-1:0] raddr_apad[ADIM];
wire inc_rreqcnt;
wire clr_rreqcnt;
reg [AW-1:0] rreqcnt;
reg [AW-1:0] rreqcnt_max;
reg [$clog2(RDFFD):0] pend_rreqcnt;

wire rdffrreq;
wire rdffrempty;
wire [BUFFD*8-1:0] rdffrdata;

reg [$clog2(BUFFD):0] trpffdepth;
wire inc_trpffwcnt;
wire clr_trpffwcnt;
reg [AW-1:0] trpffwcnt;
reg [AW-1:0] trpffwcnt_max;
wire inc_trpffrcnt;
wire clr_trpffrcnt;
reg [AW-1:0] trpffrcnt;
reg [AW-1:0] trpffrcnt_max;

reg trpffwidx;
reg trpffridx;
reg trpffvidx;

reg trpffwrdy[2];
wire trpffrrdy[2];

wire trpffinit[2];
wire trpffwreq[2];
wire trpffrreq[2];
wire [BUFFD*8-1:0] trpffwdata[2];
wire [BUFFD*8-1:0] trpffrdata[2];
wire trpffrvld[2];
reg [BUFFD*8-1:0] trpffdata;

wire waddr_req;
wire [AW-1:0] waddr_bpad[ADIM];
wire [AW-1:0] waddr_apad[ADIM];
wire inc_wreqcnt;
wire clr_wreqcnt;
reg [AW-1:0] wreqcnt;
reg [AW-1:0] wreqcnt_max;
reg lastwreq;
reg lastwreq_d[2];
reg [BUFFD*8-1:0] rdata_d[2];

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

assign rdffrreq = ~rdffrempty & trpffwrdy[trpffwidx];
fwft_fifo#(.FD(RDFFD), .DW(BUFFD*8)) u_rd_fifo(
    .clk
,   .reset_n
,   .ffwfull()
,   .ffwreq(rdata_vld)
,   .ffwdata(rdata)
,   .ffrempty(rdffrempty)
,   .ffrreq(rdffrreq)
,   .ffrdata(rdffrdata)
,   .ffrvld()
,   .ffvcnt()
);

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                               trpffdepth <= 0;
    else if(init_pulse & (mode == BIT8_MODE))  trpffdepth <= BUFFD;
    else if(init_pulse & (mode == BIT32_MODE)) trpffdepth <= (BUFFD / 4);
end

assign inc_trpffwcnt = repack_en & trpffwreq[trpffwidx];
assign clr_trpffwcnt = repack_en & trpffwreq[trpffwidx] & ((trpffwcnt == (trpffdepth - 1)) | (trpffwcnt == (trpffwcnt_max - 1)));
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)           trpffwcnt <= 0;
    else if(init_pulse)    trpffwcnt <= 0;
    else if(clr_trpffwcnt) trpffwcnt <= 0;
    else if(inc_trpffwcnt) trpffwcnt <= trpffwcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)           trpffwcnt_max <= 0;
    else if(init_pulse)    trpffwcnt_max <= packed_dim_size;
    else if(clr_trpffwcnt) trpffwcnt_max <= trpffwcnt_max > trpffdepth ? (trpffwcnt_max - trpffdepth) : packed_dim_size;
end
assign inc_trpffrcnt = repack_en & trpffrreq[trpffridx];
assign clr_trpffrcnt = repack_en & trpffrreq[trpffridx] & ((trpffrcnt == (trpffdepth - 1)) | (trpffrcnt == (trpffrcnt_max - 1)));
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)           trpffrcnt <= 0;
    else if(init_pulse)    trpffrcnt <= 0;
    else if(clr_trpffrcnt) trpffrcnt <= 0;
    else if(inc_trpffrcnt) trpffrcnt <= trpffrcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)           trpffrcnt_max <= 0;
    else if(init_pulse)    trpffrcnt_max <= unpacked_dim_size;
    else if(clr_trpffrcnt) trpffrcnt_max <= trpffrcnt_max  > trpffdepth ? (trpffrcnt_max - trpffdepth) : unpacked_dim_size;
end

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)           trpffwidx <= 0;
    else if(init_pulse)    trpffwidx <= 0;
    else if(clr_trpffwcnt) trpffwidx <= ~trpffwidx;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)           trpffridx <= 0;
    else if(init_pulse)    trpffridx <= 0;
    else if(clr_trpffrcnt) trpffridx <= ~trpffridx;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)           trpffvidx <= 0;
    else if(init_pulse)    trpffvidx <= 0;
    else                   trpffvidx <= trpffridx;
end

for(genvar i=0; i<2; i++) begin: trp_fifo
    always_ff@(posedge clk or negedge reset_n) begin
        if(~reset_n)                              trpffwrdy[i] <= 0;
        else if(init_pulse)                       trpffwrdy[i] <= 1;
        else if((trpffwidx == i) & clr_trpffwcnt) trpffwrdy[i] <= 0;
        else if((trpffridx == i) & clr_trpffrcnt) trpffwrdy[i] <= 1;
    end
    assign trpffrrdy[i] = ~trpffwrdy[i];
    assign trpffinit[i] = init_pulse | ((trpffridx == i) & clr_trpffrcnt);
    assign trpffwreq[i] = (trpffwidx == i) & rdffrreq;
    assign trpffrreq[i] = (trpffridx == i) & trpffrrdy[i] & run;
    assign trpffwdata[i] = trpffwreq[i] ? rdffrdata : 0;

    trp_fifo#(.BUFFD(BUFFD)) u_trp_fifo (
        .clk
    ,   .reset_n
    ,   .mode
    ,   .ffinit(trpffinit[i])
    ,   .ffwreq(trpffwreq[i])
    ,   .ffrreq(trpffrreq[i])
    ,   .ffwdata(trpffwdata[i])
    ,   .ffrdata(trpffrdata[i])
    ,   .ffrvld(trpffrvld[i])
    );
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        trpffdata <= 0;
    else if(init_pulse) trpffdata <= 0;
    else                trpffdata <= trpffrdata[trpffvidx];
end

assign waddr_req = repack_en ? trpffrreq[trpffridx] : rdata_vld;
for(genvar i=0; i<ADIM; i++) assign waddr_bpad[i] = 0;
for(genvar i=0; i<ADIM; i++) assign waddr_apad[i] = 0;
assign inc_wreqcnt = waddr_req;
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

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        rdata_d[0] <= 0;
    else if(init_pulse) rdata_d[0] <= 0;
    else if(~repack_en) rdata_d[0] <= rdata;
end
for(genvar i=1; i<$size(rdata_d); i++) begin
    always_ff@(posedge clk or negedge reset_n) begin
        if(~reset_n)        rdata_d[i] <= 0;
        else if(init_pulse) rdata_d[i] <= 0;
        else if(~repack_en) rdata_d[i] <= rdata_d[i-1];
    end
end

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        wdata <= 0;
    else if(init_pulse) wdata <= 0;
    else if(repack_en)  wdata <= trpffdata;
    else                wdata <= rdata_d[$size(rdata_d)-1];
end

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)                             finish <= 0;
    else if(init_pulse)                      finish <= 0;
    else if(lastwreq_d[$size(lastwreq_d)-1]) finish <= 1;
    else                                     finish <= 0;
end

endmodule: transposer