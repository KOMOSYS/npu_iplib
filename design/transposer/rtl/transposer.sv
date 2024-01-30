module transposer #(parameter AW=16, BUFFD=64, ADIM=6)(
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

typedef enum logic [1:0] {
    BIT8_MODE  = 2'b01,
    BIT32_MODE = 2'b10
} mode_t;

typedef enum logic [3:0] {
    R_IDLE  = 4'b0001,
    R_WAIT  = 4'b0010,
    R_READ  = 4'b0100,
    R_END   = 4'b1000
} rstate_t;

typedef enum logic [3:0] {
    W_IDLE  = 4'b0001,
    W_WAIT  = 4'b0010,
    W_WRITE = 4'b0100,
    W_END   = 4'b1000
} wstate_t;

rstate_t rcsm, rnsm;
wire inc_rcnt;
wire clr_rcnt;
reg [AW-1:0] rcnt;
reg [AW-1:0] rcnt_max;

wire raddr_req;
wire [AW-1:0] raddr_bpad[ADIM];
wire [AW-1:0] raddr_apad[ADIM];
wire inc_rreqcnt;
wire clr_rreqcnt;
reg [AW-1:0] rreqcnt;
reg [AW-1:0] rreqcnt_max;

wstate_t wcsm, wnsm;
wire inc_wcnt;
wire clr_wcnt;
reg [AW-1:0] wcnt;
reg [AW-1:0] wcnt_max;

wire waddr_req;
wire [AW-1:0] waddr_bpad[ADIM];
wire [AW-1:0] waddr_apad[ADIM];
wire inc_wreqcnt;
wire clr_wreqcnt;
reg [AW-1:0] wreqcnt;
reg [AW-1:0] wreqcnt_max;
reg lastwreq;
reg lastwreq_d[2];

reg ffwreqidx;
wire inc_ffwreqcnt[2];
wire clr_ffwreqcnt[2];
reg [$clog2(BUFFD):0] ffwreqcnt[2];
reg ffwvldidx;
wire inc_ffwvldcnt[2];
wire clr_ffwvldcnt[2];
reg ffrreqidx;
reg [$clog2(BUFFD):0] ffwvldcnt[2];
wire ffwrdy[2];
wire ffrrdy[2];
wire ffinit[2];
wire ffwreq[2];
wire ffrreq[2];
wire [BUFFD*8-1:0] ffwdata[2];
wire [BUFFD*8-1:0] ffrdata[2];
wire ffrvld[2];
reg [BUFFD*8-1:0] ffdata;

reg [BUFFD*8-1:0] rdata_d[2];

always_ff@(posedge clk or negedge reset_n) begin
	if (~reset_n) rcsm <= R_IDLE;
	else          rcsm <= rnsm;
end
always_comb begin
    case(rcsm)
        R_IDLE:
            if(init_pulse & repack_en)                                               rnsm = R_WAIT;
            else if(init_pulse & ~repack_en)                                         rnsm = R_READ;
            else                                                                     rnsm = R_IDLE;
        R_WAIT:
            if(ffwrdy[ffwreqidx])                                                    rnsm = R_READ;
            else                                                                     rnsm = R_WAIT;
        R_READ:
            if(~repack_en & (rreqcnt == (rreqcnt_max - 1)))                          rnsm = R_END;
            else if(repack_en & (rcnt == (rcnt_max - 1)))                            rnsm = R_END;
            else if(repack_en & (mode == BIT8_MODE) & (&rcnt[$clog2(BUFFD)-1:0]))    rnsm = R_END;
            else if(repack_en & (mode == BIT32_MODE) & (&rcnt[$clog2(BUFFD/4)-1:0])) rnsm = R_END;
            else                                                                     rnsm = R_READ;
        R_END:
            if(rreqcnt == rreqcnt_max)                                               rnsm = R_IDLE;
            else                                                                     rnsm = R_WAIT;
        default:
                                                                                     rnsm = R_IDLE;
    endcase
end
assign inc_rcnt = repack_en & (rcsm == R_READ);
assign clr_rcnt = repack_en & (rcsm == R_READ) & (rcnt == (rcnt_max - 1));
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)        rcnt <= 0;
    else if(init_pulse) rcnt <= 0;
    else if(clr_rcnt)   rcnt <= 0;
    else if(inc_rcnt)   rcnt <= rcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)        rcnt_max <= 0;
    else if(init_pulse) rcnt_max <= packed_dim_size;
end

assign raddr_req = rcsm == R_READ;
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

always_ff@(posedge clk or negedge reset_n) begin
	if (~reset_n) wcsm <= W_IDLE;
	else          wcsm <= wnsm;
end
always_comb begin
    case(wcsm)
        W_IDLE:
            if(init_pulse & repack_en)                                               wnsm = W_WAIT;
            else if(init_pulse & ~repack_en)                                         wnsm = W_WRITE;
            else                                                                     wnsm = W_IDLE;
        W_WAIT:
            if(ffrrdy[ffrreqidx])                                                    wnsm = W_WRITE;
            else                                                                     wnsm = W_WAIT;
        W_WRITE:
            if(~repack_en & (wreqcnt == (wreqcnt_max - 1)))                          wnsm = W_END;
            else if(repack_en & (wcnt == (wcnt_max - 1)))                            wnsm = W_END;
            else if(repack_en & (mode == BIT8_MODE) & (&wcnt[$clog2(BUFFD)-1:0]))    wnsm = W_END;
            else if(repack_en & (mode == BIT32_MODE) & (&wcnt[$clog2(BUFFD/4)-1:0])) wnsm = W_END;
            else                                                                     wnsm = W_WRITE;
        W_END:
            if(wreqcnt == wreqcnt_max)                                               wnsm = W_IDLE;
            else                                                                     wnsm = W_WAIT;
        default:
                                                                                     wnsm = W_IDLE;
    endcase
end
assign inc_wcnt = repack_en & (wcsm == W_WRITE);
assign clr_wcnt = repack_en & (wcsm == W_WRITE) & (wcnt == (wcnt_max - 1));
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)        wcnt <= 0;
    else if(init_pulse) wcnt <= 0;
    else if(clr_wcnt)   wcnt <= 0;
    else if(inc_wcnt)   wcnt <= wcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)        wcnt_max <= 0;
    else if(init_pulse) wcnt_max <= unpacked_dim_size;
end

assign waddr_req = repack_en ? wcsm == W_WRITE : rdata_vld;
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
    if(~reset_n)           ffwreqidx <= 0;
    else if(init_pulse)    ffwreqidx <= 0;
    else if(rcsm == R_END) ffwreqidx <= ~ffwreqidx;
end
for(genvar i=0; i<2; i++) begin
    assign inc_ffwreqcnt[i] = (ffwreqidx == i) & (rcsm == R_READ);
    assign clr_ffwreqcnt[i] = ffinit[i];
    always_ff@(posedge clk or negedge reset_n) begin 
        if(~reset_n)              ffwreqcnt[i] <= 0;
        else if(init_pulse)       ffwreqcnt[i] <= 0;
        else if(clr_ffwreqcnt[i]) ffwreqcnt[i] <= 0;
        else if(inc_ffwreqcnt[i]) ffwreqcnt[i] <= ffwreqcnt[i] + 1;
    end
end

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)                                     ffwvldidx <= 0;
    else if(init_pulse)                              ffwvldidx <= 0;
    else if(ffrrdy[ffwvldidx] & ~ffrrdy[~ffwvldidx]) ffwvldidx <= ~ffwvldidx;
end
for(genvar i=0; i<2; i++) begin
    assign inc_ffwvldcnt[i] = ffwreq[i];
    assign clr_ffwvldcnt[i] = ffinit[i];
    always_ff@(posedge clk or negedge reset_n) begin 
        if(~reset_n)              ffwvldcnt[i] <= 0;
        else if(init_pulse)       ffwvldcnt[i] <= 0;
        else if(clr_ffwvldcnt[i]) ffwvldcnt[i] <= 0;
        else if(inc_ffwvldcnt[i]) ffwvldcnt[i] <= ffwvldcnt[i] + 1;
    end
end

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)           ffrreqidx <= 0;
    else if(init_pulse)    ffrreqidx <= 0;
    else if(wcsm == W_END) ffrreqidx <= ~ffrreqidx;
end

for(genvar i=0; i<2; i++) begin: trp_fifo
    assign ffwrdy[i] = ffwreqcnt[i] == 0;
    assign ffrrdy[i] = (ffwreqcnt[i] != 0) & (ffwreqcnt[i] == ffwvldcnt[i]);

    assign ffinit[i] = (ffrreqidx == i) & (wcsm == W_END);
    assign ffwreq[i] = (ffwvldidx == i) & repack_en & rdata_vld;
    assign ffrreq[i] = (ffrreqidx == i) & (wcsm == W_WRITE);
    assign ffwdata[i] = rdata;

    trp_fifo#(.BUFFD(BUFFD)) u_trp_fifo (
        .clk
    ,   .reset_n
    ,   .mode
    ,   .ffinit(ffinit[i])
    ,   .ffwreq(ffwreq[i])
    ,   .ffrreq(ffrreq[i])
    ,   .ffwdata(ffwdata[i])
    ,   .ffrdata(ffrdata[i])
    ,   .ffrvld(ffrvld[i])
    );
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        ffdata <= 0;
    else if(init_pulse) ffdata <= 0;
    else                ffdata <= ffrdata[ffrreqidx];
end

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
    else if(repack_en)  wdata <= ffdata;
    else                wdata <= rdata_d[$size(rdata_d)-1];
end

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)                             finish <= 0;
    else if(init_pulse)                      finish <= 0;
    else if(lastwreq_d[$size(lastwreq_d)-1]) finish <= 1;
    else                                     finish <= 0;
end

endmodule: transposer