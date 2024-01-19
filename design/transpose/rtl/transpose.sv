module transpose #(parameter AW=16, BUFFD=64, ADIM=6)(
    input clk,
    input reset_n,
    input init_pulse,
    input repack_en,
    input [1:0] mode,

    input [AW-1:0] raddr_base,
    input [AW-1:0] raddr_size[ADIM],
    input [AW-1:0] raddr_stride[ADIM],
    input [AW-1:0] waddr_base,
    input [AW-1:0] waddr_size[ADIM],
    input [AW-1:0] waddr_stride[ADIM],

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
    R_WAIT  = 5'b00100,
    R_READ  = 5'b01000,
    R_END   = 5'b10000
} rstate_t;

typedef enum logic [4:0] {
    W_IDLE  = 5'b00001,
    W_SET   = 5'b00010,
    W_WAIT  = 5'b00100,
    W_WRITE = 5'b01000,
    W_END   = 5'b10000
} wstate_t;

rstate_t rcsm, rnsm;

wire inc_arreqcnt;
wire clr_arreqcnt;
reg [AW-1:0] arreqcnt;
reg [AW-1:0] arreqcnt_max;

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

reg rreqidx;
wire inc_rreqcnt[2];
wire clr_rreqcnt[2];
reg [$clog2(BUFFD):0] rreqcnt[2];
reg rvldidx;
wire inc_rvldcnt[2];
wire clr_rvldcnt[2];
reg [$clog2(BUFFD):0] rvldcnt[2];

wire trpffwrdy[2];
wire trpffrrdy[2];
wire trpffwidx;
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

always_ff@(posedge clk or negedge reset_n) begin
    if (~reset_n)      finish <= 0;
    else if(repack_en) finish <= (wcsm == W_END) & (wnsm == W_IDLE);
    else               finish <= (wcsm == W_SET) & (wnsm == W_IDLE);
end

always_ff@(posedge clk or negedge reset_n) begin
	if (~reset_n) rcsm <= R_IDLE;
	else          rcsm <= rnsm;
end
always_comb begin
    case(rcsm)
        R_IDLE:
            if(init_pulse)                                                      rnsm = R_SET;
            else                                                                rnsm = R_IDLE;
        R_SET:
            if(repack_en)                                                       rnsm = R_WAIT;
            else if(arreqcnt == (arreqcnt_max - 1))                             rnsm = R_IDLE;
            else                                                                rnsm = R_SET;
        R_WAIT:
            if(trpffwrdy[rreqidx])                                              rnsm = R_READ;
            else                                                                rnsm = R_WAIT;
        R_READ:
            if(rcnt[0] == (rcnt_max[0] - 1))                                    rnsm = R_END;
            else if((mode == BIT8_MODE) & (&rcnt[0][$clog2(BUFFD)-1:0]))        rnsm = R_END;
            else if((mode == BIT32_MODE) & (&rcnt[0][$clog2(BUFFD/4)-1:0]))     rnsm = R_END;
            else                                                                rnsm = R_READ;
        R_END:
            if((rcnt[0] == rcnt_max[0]) & (rcnt[1] == (rcnt_max[1] - 1))) begin
                if(arreqcnt == arreqcnt_max)                                    rnsm = R_IDLE;
                else                                                            rnsm = R_SET;
            end else                                                            rnsm = R_WAIT;
        default:
                                                                                rnsm = R_IDLE;
    endcase
end

assign inc_arreqcnt = rbase_req;
assign clr_arreqcnt = rcsm == R_IDLE;
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)          arreqcnt <= 0;
    else if(init_pulse)   arreqcnt <= 0;
    else if(clr_arreqcnt) arreqcnt <= 0;
    else if(inc_arreqcnt) arreqcnt <= arreqcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        arreqcnt_max <= 0;
    else if(init_pulse) arreqcnt_max <= areq_num;
end

assign inc_rcnt[0] = rcsm == R_READ;
assign clr_rcnt[0] = (rcsm == R_END) & (rcnt[0] == rcnt_max[0]);
assign inc_rcnt[1] = clr_rcnt[0];
assign clr_rcnt[1] = clr_rcnt[0] & (rcnt[1] == rcnt_max[1] - 1);
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         rcnt[0] <= 0;
    else if(init_pulse)  rcnt[0] <= 0;
    else if(clr_rcnt[0]) rcnt[0] <= 0;
    else if(inc_rcnt[0]) rcnt[0] <= rcnt[0] + 1;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         rcnt[1] <= 0;
    else if(init_pulse)  rcnt[1] <= 0;
    else if(clr_rcnt[1]) rcnt[1] <= 0;
    else if(inc_rcnt[1]) rcnt[1] <= rcnt[1] + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        rcnt_max[0] <= 0;
    else if(init_pulse) rcnt_max[0] <= packed_dim_rsize;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                               rcnt_max[1] <= 0;
    else if((mode == BIT8_MODE) & init_pulse)  rcnt_max[1] <= unpacked_dim_wsize[AW-1:$clog2(BUFFD)] + (|unpacked_dim_wsize[$clog2(BUFFD)-1:0]);
    else if((mode == BIT32_MODE) & init_pulse) rcnt_max[1] <= unpacked_dim_wsize[AW-1:$clog2(BUFFD/4)] + (|unpacked_dim_wsize[$clog2(BUFFD/4)-1:0]);
end

always_ff@(posedge clk or negedge reset_n) begin
	if (~reset_n) wcsm <= W_IDLE;
	else          wcsm <= wnsm;
end
always_comb begin
    case(wcsm)
        W_IDLE:
            if(init_pulse)                                                      wnsm = W_SET;
            else                                                                wnsm = W_IDLE;
        W_SET:
            if(repack_en)                                                       wnsm = W_WAIT;
            else if(awreqcnt == (awreqcnt_max - 1))                             wnsm = W_IDLE;
            else                                                                wnsm = W_SET;
        W_WAIT:
            if(trpffrrdy[trpffridx])                                            wnsm = W_WRITE;
            else                                                                wnsm = W_WAIT;
        W_WRITE:
            if(wcnt[0] == (wcnt_max[0] - 1))                                    wnsm = W_END;
            else if((mode == BIT8_MODE) & (&wcnt[0][$clog2(BUFFD)-1:0]))        wnsm = W_END;
            else if((mode == BIT32_MODE) & (&wcnt[0][$clog2(BUFFD/4)-1:0]))     wnsm = W_END;
            else                                                                wnsm = W_WRITE;
        W_END:
            if((wcnt[0] == wcnt_max[0]) & (wcnt[1] == (wcnt_max[1] - 1))) begin
                if(awreqcnt == awreqcnt_max)                                    wnsm = W_IDLE;
                else                                                            wnsm = W_SET;
            end else                                                            wnsm = W_WAIT;
        default:
                                                                                wnsm = W_IDLE;
    endcase
end

assign inc_awreqcnt = wbase_req;
assign clr_awreqcnt = wcsm == W_IDLE;
always_ff@(posedge clk or negedge reset_n) begin 
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
assign clr_wcnt[0] = wcsm == W_END;
assign inc_wcnt[1] = clr_wcnt[0];
assign clr_wcnt[1] = clr_wcnt[0] & (wcnt[1] == wcnt_max[1] - 1);
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         wcnt[0] <= 0;
    else if(init_pulse)  wcnt[0] <= 0;
    else if(clr_wcnt[0]) wcnt[0] <= 0;
    else if(inc_wcnt[0]) wcnt[0] <= wcnt[0] + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                                wcnt_max[0] <= 0;
    else if(init_pulse)                         wcnt_max[0] <= unpacked_dim_wsize;
    else if(wcsm == W_SET)                      wcnt_max[0] <= unpacked_dim_wsize;
    else if((mode == BIT8_MODE) & clr_wcnt[1])  wcnt_max[0] <= (wcnt_max[0] < BUFFD) ? 0 : (wcnt_max[0] - BUFFD);
    else if((mode == BIT32_MODE) & clr_wcnt[1]) wcnt_max[0] <= (wcnt_max[0] < (BUFFD/4)) ? 0 : (wcnt_max[0] - (BUFFD/4));
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)         wcnt[1] <= 0;
    else if(init_pulse)  wcnt[1] <= 0;
    else if(clr_wcnt[1]) wcnt[1] <= 0;
    else if(inc_wcnt[1]) wcnt[1] <= wcnt[1] + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                               wcnt_max[1] <= 0;
    else if((mode == BIT8_MODE) & init_pulse)  wcnt_max[1] <= packed_dim_rsize[AW-1:$clog2(BUFFD)] + (|packed_dim_rsize[$clog2(BUFFD)-1:0]);
    else if((mode == BIT32_MODE) & init_pulse) wcnt_max[1] <= packed_dim_rsize[AW-1:$clog2(BUFFD/4)] + (|packed_dim_rsize[$clog2(BUFFD/4)-1:0]);
end

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)           rreqidx <= 0;
    else if(init_pulse)    rreqidx <= 0;
    else if(rcsm == R_END) rreqidx <= ~rreqidx;
end
for(genvar i=0; i<2; i++) begin
    assign inc_rreqcnt[i] = (rreqidx == i) & (rcsm == R_READ);
    assign clr_rreqcnt[i] = (trpffridx == i) & (wcsm == W_END);
    always_ff@(posedge clk or negedge reset_n) begin 
        if(~reset_n)            rreqcnt[i] <= 0;
        else if(init_pulse)     rreqcnt[i] <= 0;
        else if(clr_rreqcnt[i]) rreqcnt[i] <= 0;
        else if(inc_rreqcnt[i]) rreqcnt[i] <= rreqcnt[i] + 1;
    end
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)                rvldidx <= 0;
    else if(init_pulse)         rvldidx <= 0;
    else if(trpffrrdy[rvldidx]) rvldidx <= ~rvldidx;
end
for(genvar i=0; i<2; i++) begin
    assign inc_rvldcnt[i] = (rvldidx == i) & rdata_vld;
    assign clr_rvldcnt[i] = (trpffridx == i) & (wcsm == W_END);
    always_ff@(posedge clk or negedge reset_n) begin 
        if(~reset_n)            rvldcnt[i] <= 0;
        else if(init_pulse)     rvldcnt[i] <= 0;
        else if(clr_rvldcnt[i]) rvldcnt[i] <= 0;
        else if(inc_rvldcnt[i]) rvldcnt[i] <= rvldcnt[i] + 1;
    end
end

assign trpffwidx = rvldidx;
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)           trpffridx <= 0;
    else if(init_pulse)    trpffridx <= 0;
    else if(wcsm == W_END) trpffridx <= ~trpffridx;
end
for(genvar i=0; i<2; i++) begin: trp_fifo
    assign trpffwrdy[i] = rreqcnt[i] == 0;
    assign trpffrrdy[i] = (rreqcnt[i] == rvldcnt[i]) & (rvldcnt[i] != 0);
    assign trpffinit[i] = (trpffridx == i) & (wcsm == W_END);
    assign trpffwreq[i] = (trpffwidx == i) & repack_en & rdata_vld;
    assign trpffrreq[i] = (trpffridx == i) & (wcsm == W_WRITE);
    assign trpffwdata[i] = ((trpffwidx == i) & repack_en) ? rdata : 0;

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
nested_addr_gen#(.DEPTH(ADIM), .AW(AW)) rbase_addr_gen(
    .clk
,   .reset_n
,   .init_pulse
,   .addr_req(rbase_req)
,   .base(raddr_base)
,   .pad_before('{ADIM{0}})
,   .size(raddr_size)
,   .pad_after('{ADIM{0}})
,   .stride(raddr_stride)
,   .addr(rbase)
,   .addr_vld(rbase_vld)
,   .pad_vld()
);
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)            packed_dim_rstride_cnt <= 0;
    else if(init_pulse)     packed_dim_rstride_cnt <= 0;
    else if(rcsm == R_SET)  packed_dim_rstride_cnt <= 0;
    else if(clr_rcnt[0])    packed_dim_rstride_cnt <= 0;
    else if(rcsm == R_READ) packed_dim_rstride_cnt <= packed_dim_rstride_cnt + packed_dim_rstride;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)           unpacked_dim_rstride_cnt <= 0;
    else if(init_pulse)    unpacked_dim_rstride_cnt <= 0;
    else if(rcsm == R_SET) unpacked_dim_rstride_cnt <= 0;
    else if(clr_rcnt[0])   unpacked_dim_rstride_cnt <= unpacked_dim_rstride_cnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                          raddr <= 0;
    else if(init_pulse)                   raddr <= 0;
    else if(repack_en & (rcsm == R_READ)) raddr <= rbase + packed_dim_rstride_cnt + unpacked_dim_rstride_cnt;
    else if(~repack_en & rbase_vld)       raddr <= rbase;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                          raddr_vld <= 0;
    else if(init_pulse)                   raddr_vld <= 0;
    else if(repack_en & (rcsm == R_READ)) raddr_vld <= 1;
    else if(~repack_en & rbase_vld)       raddr_vld <= 1;
    else                                  raddr_vld <= 0;
end

assign wbase_req = repack_en ? (wcsm == W_SET) : rdata_vld;
nested_addr_gen#(.DEPTH(ADIM), .AW(AW)) wbase_addr_gen(
    .clk
,   .reset_n
,   .init_pulse
,   .addr_req(wbase_req)
,   .base(waddr_base)
,   .pad_before('{ADIM{0}})
,   .size(waddr_size)
,   .pad_after('{ADIM{0}})
,   .stride(waddr_stride)
,   .addr(wbase)
,   .addr_vld(wbase_vld)
,   .pad_vld()
);
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                                unpacked_dim_woffset <= 0;
    else if(init_pulse)                         unpacked_dim_woffset <= 0;
    else if(wcsm == W_SET)                      unpacked_dim_woffset <= 0;
    else if(clr_wcnt[1] & (mode == BIT8_MODE))  unpacked_dim_woffset <= unpacked_dim_woffset + (unpacked_dim_wstride << $clog2(BUFFD));
    else if(clr_wcnt[1] & (mode == BIT32_MODE)) unpacked_dim_woffset <= unpacked_dim_woffset + (unpacked_dim_wstride << $clog2(BUFFD/4));
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)             unpacked_dim_wstride_cnt <= 0;
    else if(init_pulse)      unpacked_dim_wstride_cnt <= 0;
    else if(wcsm == W_SET)   unpacked_dim_wstride_cnt <= 0;
    else if(wcsm == W_END)   unpacked_dim_wstride_cnt <= 0;
    else if(wcsm == W_WRITE) unpacked_dim_wstride_cnt <= unpacked_dim_wstride_cnt + unpacked_dim_wstride;
end
always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)           packed_dim_wstride_cnt <= 0;
    else if(init_pulse)    packed_dim_wstride_cnt <= 0;
    else if(wcsm == W_SET) packed_dim_wstride_cnt <= 0;
    else if(clr_wcnt[1])   packed_dim_wstride_cnt <= 0;
    else if(clr_wcnt[0])   packed_dim_wstride_cnt <= packed_dim_wstride_cnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                              waddr_tmp <= 0;
    else if(init_pulse)                       waddr_tmp <= 0;
    else if(repack_en & trpffrreq[trpffridx]) waddr_tmp <= wbase + unpacked_dim_woffset + unpacked_dim_wstride_cnt + packed_dim_wstride_cnt;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                              waddr <= 0;
    else if(init_pulse)                       waddr <= 0;
    else if(repack_en & trpffrvld[trpffridx]) waddr <= waddr_tmp;
    else if(~repack_en & wbase_vld)           waddr <= wbase;
end

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                    rdata_tmp <= 0;
    else if(init_pulse)             rdata_tmp <= 0;
    else if(~repack_en & rdata_vld) rdata_tmp <= rdata;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                              wdata <= 0;
    else if(init_pulse)                       wdata <= 0;
    else if(repack_en & trpffrvld[trpffridx]) wdata <= trpffrdata[trpffridx];
    else if(~repack_en & wbase_vld)           wdata <= rdata_tmp;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                              wdata_vld <= 0;
    else if(init_pulse)                       wdata_vld <= 0;
    else if(repack_en & trpffrvld[trpffridx]) wdata_vld <= 1;
    else if(~repack_en & wbase_vld)           wdata_vld <= 1;
    else                                      wdata_vld <= 0;
end
endmodule: transpose