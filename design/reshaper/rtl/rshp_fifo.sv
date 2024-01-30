module rshp_fifo #(parameter DW=512, BUFFW=512*3)(
    input clk,
    input reset_n,
    input init_pulse,

    input ffwreq,
    input [$clog2(DW/8):0] ffwbyte,
    input [(DW/8)-1:0][7:0] ffwdata,

    input ffrreq,
    input [$clog2(DW/8):0]  ffrbyte,
    output reg [(DW/8)-1:0][7:0] ffrdata,
    output reg ffrvld,
    output reg [$clog2(BUFFW/8):0] ffvbyte
);

reg [BUFFW/8-1:0][7:0] buffer;

wire [BUFFW+DW-1:0] wdata_tmp;
wire [BUFFW/8-1:0][7:0] wdata;
wire [BUFFW+DW-1:0] wmask_tmp;
wire [BUFFW/8-1:0][7:0] wmask;
reg [$clog2(BUFFW/8)-1:0] wptr;

wire [DW-1:0] rdata;
reg [$clog2(BUFFW/8)-1:0] rptr;

assign wdata_tmp = ffwdata << (wptr*8);
assign wdata = wdata_tmp[BUFFW-1:0] | wdata_tmp[BUFFW+DW-1:BUFFW];
assign wmask_tmp = {DW{1'b1}} << (wptr*8);
assign wmask = wmask_tmp[BUFFW-1:0] | wmask_tmp[BUFFW+DW-1:BUFFW];

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        buffer <= 8'b0;
    else if(init_pulse) buffer <= 8'b0;
    else if(ffwreq)     buffer <= (buffer & ~wmask) | wdata;
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)        wptr <= 0;
    else if(init_pulse) wptr <= 0;
    else if(ffwreq)     wptr <= (wptr + ffwbyte) >= (BUFFW/8) ? (wptr + ffwbyte) - (BUFFW/8): (wptr + ffwbyte);
end

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)             ffvbyte <= 0;
    else if(init_pulse)      ffvbyte <= 0;
    else if(ffwreq & ffrreq) ffvbyte <= ffvbyte + ffwbyte - ffrbyte;
    else if(ffwreq)          ffvbyte <= ffvbyte + ffwbyte;
    else if(ffrreq)          ffvbyte <= ffvbyte - ffrbyte;
end

assign rdata = {buffer[DW/8-1:0], buffer[BUFFW/8-1:0]} >> (rptr*8);
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        ffrdata <= 8'b0;
    else if(init_pulse) ffrdata <= 8'b0;
    else if(ffrreq)     ffrdata <= rdata;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)        ffrvld <= 0;
    else if(init_pulse) ffrvld <= 0;
    else if(ffrreq)     ffrvld <= 1;
    else                ffrvld <= 0;
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)        rptr <= 0;
    else if(init_pulse) rptr <= 0;
    else if(ffrreq)     rptr <= (rptr + ffrbyte) >= (BUFFW/8) ? (rptr + ffrbyte) - (BUFFW/8): (rptr + ffrbyte);
end

endmodule: rshp_fifo