module transpose #(parameter AW=16, BUFFD=64, ADIMD=6)(
    input clk,
    input reset_n,
    input init_pulse,
    input repack_en,
    input [1:0] mode,

    input [AW-1:0] raddr_base,
	input [AW-1:0] raddr_size[ADIMD],
	input [AW-1:0] raddr_stride[ADIMD],
    input [AW-1:0] waddr_base,
    input [AW-1:0] waddr_size[ADIMD],
	input [AW-1:0] waddr_stride[ADIMD],

    input [AW-1:0] areq_num,

    input [AW-1:0] packed_dim_rsize,
    input [AW-1:0] packed_dim_rstride,
    input [AW-1:0] unpacked_dim_wsize,
    input [AW-1:0] unpacked_dim_wstride,

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

typedef enum logic [4:0] {
    R_IDLE  = 5'b00001,
    R_SET   = 5'b00010,
    R_READ  = 5'b00100,
    R_WAIT  = 5'b01000,
    R_END   = 5'b10000
} rstate_t;

typedef enum logic [3:0] {
    W_IDLE  = 4'b00001,
    W_SET   = 4'b00010,
    W_WRITE = 4'b00100,
    W_END   = 4'b01000
} wstate_t;

rstate_t rcsm, rnsm;

wire inc_arreqcnt;
wire clr_arreqcnt;
reg [AW-1:0] arreqcnt;
reg [AW-1:0] arreqcnt_max;

wire inc_rreqcnt;
wire clr_rreqcnt;
reg [$clog2(BUFFD)-1:0] rreqcnt;
wire inc_rvldcnt;
wire clr_rvldcnt;
reg [$clog2(BUFFD)-1:0] rvldcnt;

wire inc_rcnt[2];
wire clr_rcnt[2];
reg [AW-1:0] rcnt[2];
reg [AW-1:0] rcnt_max[2];

wstate_t wcsm, wnsm;

wire inc_awreqcnt;
wire clr_awreqcnt;
reg [AW-1:0] awreqcnt;
reg [AW-1:0] awreqcnt_max;

wire inc_wcnt[2];
wire clr_wcnt[2];
reg [AW-1:0] wcnt[2];
reg [AW-1:0] wcnt_max[2];

reg trpffwidx;
reg trpffridx;
wire trpffinit[2];
wire trpffwreq[2];
wire trpffrreq[2];
wire [BUFFD*8-1:0] trpffwdata[2];
wire [BUFFD*8-1:0] trpffrdata[2];
wire trpffrvld[2];

wire rbase_req;
reg [AW-1:0] rbase;
wire rbase_vld;
reg [AW-1:0] packed_dim_rstride_cnt;
reg [AW-1:0] unpacked_dim_rstride_cnt;

wire wbase_req;
reg [AW-1:0] wbase;
wire wbase_vld;
reg [AW-1:0] unpacked_dim_wstride_cnt;
reg [AW-1:0] unpacked_dim_woffset;
reg [AW-1:0] packed_dim_wstride_cnt;

reg [AW-1:0] raddr_tmp;
reg [AW-1:0] waddr_tmp;
reg [BUFFD*8-1:0] rdata_tmp;

always@(posedge clk or negedge reset_n) begin
    if (~reset_n)      finish <= 0;
    else if(repack_en) finish <= (wcsm == W_END) & (wnsm == W_IDLE);
    else               finish <= (wcsm == W_SET) & (wnsm == W_IDLE);
end

always@(posedge clk or negedge reset_n) begin
	if (~reset_n) rcsm <= R_IDLE;
	else          rcsm <= rnsm;
end
always_comb begin
    case(rcsm)
        R_IDLE:
            if(init_pulse)                                                                             rnsm = R_SET;
            else                                                                                       rnsm = R_IDLE;
        R_SET:
            if(repack_en)                                                                              rnsm = R_READ;
            else if(arreqcnt == (arreqcnt_max - 1))                                                    rnsm = R_IDLE;
            else                                                                                       rnsm = R_SET;
        R_READ:
            if(rcnt[0] == (rcnt_max[0] - 1))                                                           rnsm = R_WAIT;
            else if((mode == BIT8_MODE) & (&rcnt[0][$clog2(BUFFD)-1:0]))                               rnsm = R_WAIT;
            else if((mode == BIT32_MODE) & (&rcnt[0][$clog2(BUFFD/4)-1:0]))                            rnsm = R_WAIT;
            else                                                                                       rnsm = R_READ;
        R_WAIT:
            if(rreqcnt == rvldcnt)                                                                     rnsm = R_END;
            else                                                                                       rnsm = R_WAIT;
        R_END:
            if((rcnt[0] == rcnt_max[0]) & (rcnt[1] == (rcnt_max[1] - 1)) & (arreqcnt == arreqcnt_max)) rnsm = R_IDLE;
            else if((wcsm == W_IDLE | wcsm == W_END)) begin
                if((rcnt[0] == rcnt_max[0]) & (rcnt[1] == (rcnt_max[1] - 1)))                          rnsm = R_SET;
                else                                                                                   rnsm = R_READ;
            end
            else                                                                                       rnsm = R_END;
        default:
                                                                                                       rnsm = R_IDLE;
    endcase
end

assign inc_arreqcnt = rbase_req;
assign clr_arreqcnt = rcsm == R_IDLE;
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)          arreqcnt <= 0;
    else if(init_pulse)   arreqcnt <= 0;
    else if(clr_arreqcnt) arreqcnt <= 0;
    else if(inc_arreqcnt) arreqcnt <= arreqcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        arreqcnt_max <= 0;
    else if(init_pulse) arreqcnt_max <= areq_num;
end

assign inc_rreqcnt = rcsm == R_READ;
assign clr_rreqcnt = rcsm == R_END;
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         rreqcnt <= 0;
    else if(init_pulse)  rreqcnt <= 0;
    else if(clr_rreqcnt) rreqcnt <= 0;
    else if(inc_rreqcnt) rreqcnt <= rreqcnt + 1;
end

assign inc_rvldcnt = repack_en & rdata_vld;
assign clr_rvldcnt = rcsm == R_END;
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)         rvldcnt <= 0;
    else if(init_pulse)  rvldcnt <= 0;
    else if(clr_rvldcnt) rvldcnt <= 0;
    else if(inc_rvldcnt) rvldcnt <= rvldcnt + 1;
end

assign inc_rcnt[0] = rcsm == R_READ;
assign clr_rcnt[0] = (rcsm == R_END) & (rnsm != R_END) & (rcnt[0] == rcnt_max[0]);
assign inc_rcnt[1] = clr_rcnt[0];
assign clr_rcnt[1] = clr_rcnt[0] & (rcnt[1] == rcnt_max[1] - 1);
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         rcnt[0] <= 0;
    else if(init_pulse)  rcnt[0] <= 0;
    else if(clr_rcnt[0]) rcnt[0] <= 0;
    else if(inc_rcnt[0]) rcnt[0] <= rcnt[0] + 1;
end
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         rcnt[1] <= 0;
    else if(init_pulse)  rcnt[1] <= 0;
    else if(clr_rcnt[1]) rcnt[1] <= 0;
    else if(inc_rcnt[1]) rcnt[1] <= rcnt[1] + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        rcnt_max[0] <= 0;
    else if(init_pulse) rcnt_max[0] <= packed_dim_rsize;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n)                               rcnt_max[1] <= 0;
    else if((mode == BIT8_MODE) & init_pulse)  rcnt_max[1] <= unpacked_dim_wsize[AW-1:$clog2(BUFFD)] + (|unpacked_dim_wsize[$clog2(BUFFD)-1:0]);
    else if((mode == BIT32_MODE) & init_pulse) rcnt_max[1] <= unpacked_dim_wsize[AW-1:$clog2(BUFFD/4)] + (|unpacked_dim_wsize[$clog2(BUFFD/4)-1:0]);
end

always@(posedge clk or negedge reset_n) begin
	if (~reset_n) wcsm <= W_IDLE;
	else          wcsm <= wnsm;
end
always_comb begin
    case(wcsm)
        W_IDLE:
            if(init_pulse & ~repack_en)                                                                wnsm = W_SET;
            else if(rcsm == R_END)                                                                     wnsm = W_SET;
            else                                                                                       wnsm = W_IDLE;
        W_SET:
            if(repack_en)                                                                              wnsm = W_WRITE;
            else if(awreqcnt == (awreqcnt_max - 1))                                                    wnsm = W_IDLE;
            else                                                                                       wnsm = W_SET;
        W_WRITE:
            if(wcnt[0] == (wcnt_max[0] - 1))                                                           wnsm = W_END;
            else if((mode == BIT8_MODE) & (&wcnt[0][$clog2(BUFFD)-1:0]))                               wnsm = W_END;
            else if((mode == BIT32_MODE) & (&wcnt[0][$clog2(BUFFD/4)-1:0]))                            wnsm = W_END;
            else                                                                                       wnsm = W_WRITE;
        W_END:
            if((wcnt[0] == wcnt_max[0]) & (wcnt[1] == (wcnt_max[1] - 1)) & (awreqcnt == awreqcnt_max)) wnsm = W_IDLE;
            else if(rcsm == R_IDLE | rcsm == R_END) begin
                if((wcnt[0] == wcnt_max[0]) & (wcnt[1] == (wcnt_max[1] - 1)))                          wnsm = W_SET;
                else                                                                                   wnsm = W_WRITE;
            end
            else                                                                                       wnsm = W_END;
        default:
                                                                                                       wnsm = W_IDLE;
    endcase
end

assign inc_awreqcnt = wbase_req;
assign clr_awreqcnt = wcsm == W_IDLE;
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)          awreqcnt <= 0;
    else if(init_pulse)   awreqcnt <= 0;
    else if(clr_awreqcnt) awreqcnt <= 0;
    else if(inc_awreqcnt) awreqcnt <= awreqcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        awreqcnt_max <= 0;
    else if(init_pulse) awreqcnt_max <= areq_num;
end

assign inc_wcnt[0] = wcsm == W_WRITE;
assign clr_wcnt[0] = (wcsm == W_END) & (wnsm != W_END);
assign inc_wcnt[1] = clr_wcnt[0];
assign clr_wcnt[1] = clr_wcnt[0] & (wcnt[1] == wcnt_max[1] - 1);
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         wcnt[0] <= 0;
    else if(init_pulse)  wcnt[0] <= 0;
    else if(clr_wcnt[0]) wcnt[0] <= 0;
    else if(inc_wcnt[0]) wcnt[0] <= wcnt[0] + 1;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n)                                wcnt_max[0] <= 0;
    else if(init_pulse)                         wcnt_max[0] <= unpacked_dim_wsize;
    else if(wcsm == W_SET)                      wcnt_max[0] <= unpacked_dim_wsize;
    else if((mode == BIT8_MODE) & clr_wcnt[1])  wcnt_max[0] <= (wcnt_max[0] < BUFFD) ? 0 : (wcnt_max[0] - BUFFD);
    else if((mode == BIT32_MODE) & clr_wcnt[1]) wcnt_max[0] <= (wcnt_max[0] < (BUFFD/4)) ? 0 : (wcnt_max[0] - (BUFFD/4));
end
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         wcnt[1] <= 0;
    else if(init_pulse)  wcnt[1] <= 0;
    else if(clr_wcnt[1]) wcnt[1] <= 0;
    else if(inc_wcnt[1]) wcnt[1] <= wcnt[1] + 1;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n)                               wcnt_max[1] <= 0;
    else if((mode == BIT8_MODE) & init_pulse)  wcnt_max[1] <= packed_dim_rsize[AW-1:$clog2(BUFFD)] + (|packed_dim_rsize[$clog2(BUFFD)-1:0]);
    else if((mode == BIT32_MODE) & init_pulse) wcnt_max[1] <= packed_dim_rsize[AW-1:$clog2(BUFFD/4)] + (|packed_dim_rsize[$clog2(BUFFD/4)-1:0]);
end

always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                               trpffwidx <= 0;
    else if(init_pulse)                        trpffwidx <= 0;
    else if((rcsm == R_END) & (rnsm != R_END)) trpffwidx <= ~trpffwidx;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                               trpffridx <= 0;
    else if(init_pulse)                        trpffridx <= 0;
    else if((wcsm == W_END) & (wnsm != W_END)) trpffridx <= ~trpffridx;
end
for(genvar i=0; i<2; i++) begin
    assign trpffinit[i] = (trpffridx == i) & (wcsm == W_END);
    assign trpffwreq[i] = (trpffwidx == i) & repack_en & rdata_vld;
    assign trpffrreq[i] = (trpffridx == i) & (wcsm == W_WRITE);
    assign trpffwdata[i] = ((trpffwidx == i) & repack_en) ? rdata : 0;
end
for(genvar i=0; i<2; i++) begin: trp_fifo
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

assign rbase_req = rcsm == R_SET;
nested_addr_gen#(.DEPTH(ADIMD), .AW(AW)) rbase_addr_gen(
    .clk
,   .reset_n
,   .init_pulse
,   .addr_req(rbase_req)
,   .base(raddr_base)
,   .size(raddr_size)
,   .stride(raddr_stride)
,   .addr(rbase)
,   .addr_vld(rbase_vld)
);
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)            packed_dim_rstride_cnt <= 0;
    else if(init_pulse)     packed_dim_rstride_cnt <= 0;
    else if(rcsm == R_SET)  packed_dim_rstride_cnt <= 0;
    else if(clr_rcnt[0])    packed_dim_rstride_cnt <= 0;
    else if(rcsm == R_READ) packed_dim_rstride_cnt <= packed_dim_rstride_cnt + packed_dim_rstride;
end
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)           unpacked_dim_rstride_cnt <= 0;
    else if(init_pulse)    unpacked_dim_rstride_cnt <= 0;
    else if(rcsm == R_SET) unpacked_dim_rstride_cnt <= 0;
    else if(clr_rcnt[0])   unpacked_dim_rstride_cnt <= unpacked_dim_rstride_cnt + 1;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                          raddr <= 0;
    else if(init_pulse)                   raddr <= 0;
    else if(repack_en & (rcsm == R_READ)) raddr <= rbase + packed_dim_rstride_cnt + unpacked_dim_rstride_cnt;
    else if(~repack_en & rbase_vld)       raddr <= rbase;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                          raddr_vld <= 0;
    else if(init_pulse)                   raddr_vld <= 0;
    else if(repack_en & (rcsm == R_READ)) raddr_vld <= 1;
    else if(~repack_en & rbase_vld)       raddr_vld <= 1;
    else                                  raddr_vld <= 0;
end

assign wbase_req = repack_en ? (wcsm == W_SET) : rdata_vld;
nested_addr_gen#(.DEPTH(ADIMD), .AW(AW)) wbase_addr_gen(
    .clk
,   .reset_n
,   .init_pulse
,   .addr_req(wbase_req)
,   .base(waddr_base)
,   .size(waddr_size)
,   .stride(waddr_stride)
,   .addr(wbase)
,   .addr_vld(wbase_vld)
);
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                                unpacked_dim_woffset <= 0;
    else if(init_pulse)                         unpacked_dim_woffset <= 0;
    else if(wcsm == W_SET)                      unpacked_dim_woffset <= 0;
    else if(clr_wcnt[1] & (mode == BIT8_MODE))  unpacked_dim_woffset <= unpacked_dim_woffset + (unpacked_dim_wstride << $clog2(BUFFD));
    else if(clr_wcnt[1] & (mode == BIT32_MODE)) unpacked_dim_woffset <= unpacked_dim_woffset + (unpacked_dim_wstride << $clog2(BUFFD/4));
end
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)             unpacked_dim_wstride_cnt <= 0;
    else if(init_pulse)      unpacked_dim_wstride_cnt <= 0;
    else if(wcsm == W_SET)   unpacked_dim_wstride_cnt <= 0;
    else if(wcsm == W_END)   unpacked_dim_wstride_cnt <= 0;
    else if(wcsm == W_WRITE) unpacked_dim_wstride_cnt <= unpacked_dim_wstride_cnt + unpacked_dim_wstride;
end
always@(posedge clk or negedge reset_n) begin 
    if(~reset_n)           packed_dim_wstride_cnt <= 0;
    else if(init_pulse)    packed_dim_wstride_cnt <= 0;
    else if(wcsm == W_SET) packed_dim_wstride_cnt <= 0;
    else if(clr_wcnt[1])   packed_dim_wstride_cnt <= 0;
    else if(clr_wcnt[0])   packed_dim_wstride_cnt <= packed_dim_wstride_cnt + 1;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                              waddr_tmp <= 0;
    else if(init_pulse)                       waddr_tmp <= 0;
    else if(repack_en & trpffrreq[trpffridx]) waddr_tmp <= wbase + unpacked_dim_woffset + unpacked_dim_wstride_cnt + packed_dim_wstride_cnt;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                              waddr <= 0;
    else if(init_pulse)                       waddr <= 0;
    else if(repack_en & trpffrvld[trpffridx]) waddr <= waddr_tmp;
    else if(~repack_en & wbase_vld)           waddr <= wbase;
end

always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                    rdata_tmp <= 0;
    else if(init_pulse)             rdata_tmp <= 0;
    else if(~repack_en & rdata_vld) rdata_tmp <= rdata;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                              wdata <= 0;
    else if(init_pulse)                       wdata <= 0;
    else if(repack_en & trpffrvld[trpffridx]) wdata <= trpffrdata[trpffridx];
    else if(~repack_en & wbase_vld)           wdata <= rdata_tmp;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)        wdata_vld <= 0;
    else if(init_pulse) wdata_vld <= 0;
    else if(repack_en)  wdata_vld <= trpffrvld[trpffridx];
    else if(~repack_en) wdata_vld <= wbase_vld;
    else                wdata_vld <= 0;
end
endmodule: transpose