module transpose #(parameter AW=16, BUFFD=64, DIMD=6)(
    input clk,
    input reset_n,
    input init_pulse,
    input repack_en,
    input [1:0] mode,

    input [AW-1:0] raddr_base,
	input [AW-1:0] raddr_size[DIMD],
	input [AW-1:0] raddr_stride[DIMD],
    input [AW-1:0] waddr_base,
    input [AW-1:0] waddr_size[DIMD],
	input [AW-1:0] waddr_stride[DIMD],

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
    output reg wdata_vld
);

typedef enum logic [1:0] {
    BIT8_MODE = 2'b01,
    BIT32_MODE = 2'b10
} mode_t;
typedef enum logic [5:0] {
    ST_IDLE  = 6'b000001,
    ST_SET   = 6'b000010,
    ST_READ  = 6'b000100,
    ST_WAIT  = 6'b001000,
    ST_WRITE = 6'b010000,
    ST_END   = 6'b100000
} state_t;

state_t csm, nsm;

wire inc_rcnt;
wire clr_rcnt;
reg [AW-1:0] rcnt;
reg [AW-1:0] rcnt_max;

wire inc_rreqcnt;
wire clr_rreqcnt;
reg [$clog2(BUFFD)-1:0] rreqcnt;
wire inc_rvldcnt;
wire clr_rvldcnt;
reg [$clog2(BUFFD)-1:0] rvldcnt;

wire inc_wcnt;
wire clr_wcnt;
reg [AW-1:0] wcnt;
reg [AW-1:0] wcnt_max;

wire inc_areqcnt;
wire clr_areqcnt;
reg [AW-1:0] areqcnt;
reg [AW-1:0] areqcnt_max;

wire trpffinit;
wire trpffwreq;
wire trpffrreq;
wire [BUFFD*8-1:0] trpffwdata;
wire [BUFFD*8-1:0] trpffrdata;
wire trpffrvld;

reg [AW-1:0] rbase;
wire rbase_vld;

reg [AW-1:0] wbase;
wire wbase_vld;

reg [AW-1:0] packed_dim_rstride_cnt;
reg [AW-1:0] unpacked_dim_rstride_cnt;

reg [AW-1:0] unpacked_dim_wstride_cnt;
reg [AW-1:0] unpacked_dim_woffset;
reg [AW-1:0] packed_dim_wstride_cnt;

reg [AW-1:0] raddr_tmp;
reg [AW-1:0] waddr_tmp;
reg [BUFFD*8-1:0] rdata_tmp;

always@(posedge clk or negedge reset_n) begin
	if (~reset_n) csm <= ST_IDLE;
	else          csm <= nsm;
end
always_comb begin
    case(csm)
        ST_IDLE:
            if(init_pulse)                                                       nsm = ST_SET;
            else                                                                 nsm = ST_IDLE;
        ST_SET:
            if(repack_en)                                                        nsm = ST_READ;
            else if(areqcnt == (areqcnt_max -1))                                 nsm = ST_IDLE;
            else                                                                 nsm = ST_SET;
        ST_READ:
            if(rcnt == (rcnt_max - 1))                                           nsm = ST_WAIT;
            else if((mode == BIT8_MODE) & (rcnt[5:0] == (1<<6) - 1))             nsm = ST_WAIT;
            else if((mode == BIT32_MODE) & (rcnt[3:0] == (1<<4) - 1))            nsm = ST_WAIT;
            else                                                                 nsm = ST_READ;
        ST_WAIT:
            if(rvldcnt == rreqcnt)                                               nsm = ST_WRITE;
            else                                                                 nsm = ST_WAIT;
        ST_WRITE:
            if(wcnt == (wcnt_max - 1))                                           nsm = ST_END;
            else if((mode == BIT8_MODE) & (wcnt[5:0] == (1<<6) - 1))             nsm = ST_END;
            else if((mode == BIT32_MODE) & (wcnt[3:0] == (1<<4) - 1))            nsm = ST_END;
            else                                                                 nsm = ST_WRITE;
        ST_END:
            if((rcnt == rcnt_max) & (wcnt == wcnt_max) & (areqcnt == areqcnt_max)) nsm = ST_IDLE;
            else if((rcnt == rcnt_max) & (wcnt == wcnt_max))                     nsm = ST_SET;
            else                                                                 nsm = ST_READ;
    endcase
end

assign inc_rcnt = csm == ST_READ;
assign clr_rcnt = csm == ST_END & (rcnt == rcnt_max);
always@(posedge clk or negedge reset_n) begin 
    if(!reset_n)        rcnt <= 0;
    else if(init_pulse) rcnt <= 0;
    else if(clr_rcnt)   rcnt <= 0;
    else if(inc_rcnt)   rcnt <= rcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        rcnt_max <= 0;
    else if(init_pulse) rcnt_max <= packed_dim_rsize;
end

assign inc_rreqcnt = csm == ST_READ;
assign clr_rreqcnt = csm == ST_END;
always@(posedge clk or negedge reset_n) begin 
    if(!reset_n)         rreqcnt <= 0;
    else if(init_pulse)  rreqcnt <= 0;
    else if(clr_rreqcnt) rreqcnt <= 0;
    else if(inc_rreqcnt) rreqcnt <= rreqcnt + 1;
end

assign inc_rvldcnt = repack_en & rdata_vld;
assign clr_rvldcnt = csm == ST_END;
always@(posedge clk or negedge reset_n) begin 
    if(!reset_n)         rvldcnt <= 0;
    else if(init_pulse)  rvldcnt <= 0;
    else if(clr_rvldcnt) rvldcnt <= 0;
    else if(inc_rvldcnt) rvldcnt <= rvldcnt + 1;
end

assign inc_wcnt = (csm == ST_WRITE);
assign clr_wcnt = (csm == ST_END);
always@(posedge clk or negedge reset_n) begin 
    if(!reset_n)        wcnt <= 0;
    else if(init_pulse) wcnt <= 0;
    else if(clr_wcnt)   wcnt <= 0;
    else if(inc_wcnt)   wcnt <= wcnt + 1;
end
always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n)                             wcnt_max <= 0;
    else if(init_pulse)                      wcnt_max <= unpacked_dim_wsize;
    else if(csm == ST_SET)                   wcnt_max <= unpacked_dim_wsize;
    else if((mode == BIT8_MODE) & clr_rcnt)  wcnt_max <= wcnt_max < (1<<6) ? 0 : wcnt_max - (1<<6);
    else if((mode == BIT32_MODE) & clr_rcnt) wcnt_max <= wcnt_max < (1<<4) ? 0 : wcnt_max - (1<<4);
end

assign inc_areqcnt = (csm == ST_SET);
assign clr_areqcnt = (csm == ST_IDLE);
always@(posedge clk or negedge reset_n) begin 
    if(!reset_n)         areqcnt <= 0;
    else if(init_pulse)  areqcnt <= 0;
    else if(clr_areqcnt) areqcnt <= 0;
    else if(inc_areqcnt) areqcnt <= areqcnt + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        areqcnt_max <= 0;
    else if(init_pulse) areqcnt_max <= areq_num;
end

assign trpffinit = csm == ST_END;
assign trpffwreq = repack_en & rdata_vld;
assign trpffrreq = csm == ST_WRITE;
assign trpffwdata = repack_en ? rdata : 0;
trp_fifo#(.BUFFD(BUFFD)) u_trp_fifo (
        .clk
    ,   .reset_n
    ,   .mode
    ,   .ffinit(csm == ST_END)
    ,   .ffwreq(repack_en & rdata_vld)
    ,   .ffrreq(csm == ST_WRITE)
    ,   .ffwdata(rdata)
    ,   .ffrdata(trpffrdata)
    ,   .ffrvld(trpffrvld)
);

nested_addr_gen#(.DEPTH(DIMD), .AW(AW)) rbase_addr_gen(
        .clk
    ,   .reset_n
    ,   .init_pulse
    ,   .addr_req(csm == ST_SET)
    ,   .base(raddr_base)
    ,   .size(raddr_size)
    ,   .stride(raddr_stride)
    ,   .addr(rbase)
    ,   .addr_vld(rbase_vld)
);

nested_addr_gen#(.DEPTH(DIMD), .AW(AW)) wbase_addr_gen(
        .clk
    ,   .reset_n
    ,   .init_pulse
    ,   .addr_req(repack_en ? csm == ST_SET : rdata_vld)
    ,   .base(waddr_base)
    ,   .size(waddr_size)
    ,   .stride(waddr_stride)
    ,   .addr(wbase)
    ,   .addr_vld(wbase_vld)
);

always@(posedge clk or negedge reset_n) begin 
    if(!reset_n)                                  packed_dim_rstride_cnt <= 0;
    else if(csm == ST_SET)                        packed_dim_rstride_cnt <= 0;
    else if((csm == ST_END) & (rcnt == rcnt_max)) packed_dim_rstride_cnt <= 0;
    else if(csm == ST_READ)                       packed_dim_rstride_cnt <= packed_dim_rstride_cnt + packed_dim_rstride;
end
always@(posedge clk or negedge reset_n) begin 
    if(!reset_n)                                  unpacked_dim_rstride_cnt <= 0;
    else if(csm == ST_SET)                        unpacked_dim_rstride_cnt <= 0;
    else if((csm == ST_END) & (rcnt == rcnt_max)) unpacked_dim_rstride_cnt <= unpacked_dim_rstride_cnt + 1;
end

always@(posedge clk or negedge reset_n) begin
    if(!reset_n)                             unpacked_dim_woffset <= 0;
    else if(csm == ST_SET)                   unpacked_dim_woffset <= 0;
    else if((mode == BIT8_MODE) & clr_rcnt)  unpacked_dim_woffset <= unpacked_dim_woffset + (unpacked_dim_wstride << 6);
    else if((mode == BIT32_MODE) & clr_rcnt) unpacked_dim_woffset <= unpacked_dim_woffset + (unpacked_dim_wstride << 4);
end
always@(posedge clk or negedge reset_n) begin 
    if(!reset_n)             unpacked_dim_wstride_cnt <= 0;
    else if(csm == ST_SET)   unpacked_dim_wstride_cnt <= 0; 
    else if(csm == ST_READ)  unpacked_dim_wstride_cnt <= unpacked_dim_woffset;
    else if(csm == ST_WRITE) unpacked_dim_wstride_cnt <= unpacked_dim_wstride_cnt + unpacked_dim_wstride;
end
always@(posedge clk or negedge reset_n) begin 
    if(!reset_n)                                  packed_dim_wstride_cnt <= 0;
    else if(csm == ST_SET)                        packed_dim_wstride_cnt <= 0;
    else if((csm == ST_END) & (rcnt == rcnt_max)) packed_dim_wstride_cnt <= 0;
    else if(csm == ST_END)                        packed_dim_wstride_cnt <= packed_dim_wstride_cnt + 1;
end

always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                          raddr <= 0;
    else if(repack_en & (csm == ST_READ)) raddr <= rbase + packed_dim_rstride_cnt + unpacked_dim_rstride_cnt;
    else if(!repack_en & rbase_vld)       raddr <= rbase;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                          raddr_vld <= 0;
    else if(repack_en & (csm == ST_READ)) raddr_vld <= 1;
    else if(!repack_en & rbase_vld)       raddr_vld <= 1;
    else                                  raddr_vld <= 0;
end

always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                    waddr_tmp <= 0;
    else if(repack_en & trpffrreq)  waddr_tmp <= wbase + unpacked_dim_wstride_cnt + packed_dim_wstride_cnt;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                    waddr <= 0;
    else if(repack_en & trpffrvld)  waddr <= waddr_tmp;
    else if(!repack_en & wbase_vld) waddr <= wbase;
end

always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                    rdata_tmp <= 0;
    else if(!repack_en & rdata_vld) rdata_tmp <= rdata;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                    wdata <= 0;
    else if(repack_en & trpffrvld)  wdata <= trpffrdata;
    else if(!repack_en & wbase_vld) wdata <= rdata_tmp;
end
always@(posedge clk or negedge reset_n) begin
    if(~reset_n)                    wdata_vld <= 0;
    else if(repack_en & trpffrvld)  wdata_vld <= 1;
    else if(!repack_en & wbase_vld) wdata_vld <= 1;
    else                            wdata_vld <= 0;
end
endmodule: transpose