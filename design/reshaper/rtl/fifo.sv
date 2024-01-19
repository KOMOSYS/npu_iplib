module fifo #(parameter FD=8, DW=8)(
    input clk,
    input reset_n,
    input ffwreq,
    input [DW-1:0] ffwdata,
    input ffrreq,
    output reg [DW-1:0] ffrdata,
    output reg ffrvld,
    output reg [$clog2(FD):0] ffvcnt,
    output reg ffwfull,
    output reg ffrempty
);

reg [FD-1:0][DW-1:0] buffer;
reg [$clog2(FD)-1:0] wptr, rptr;

assign ffwfull = ffvcnt >= FD;
assign ffrempty = ffvcnt == 0;

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)    wptr <= 0;
    else if(ffwreq) wptr <= wptr != (FD - 1) ? wptr + 1 : 0;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)    buffer <= 0;
    else if(ffwreq) buffer[wptr] <= ffwdata;
end

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)    rptr <= 0;
    else if(ffrreq) rptr <= rptr != (FD - 1) ? rptr + 1 : 0;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)    ffrdata <= 0;
    else if(ffrreq) ffrdata <= buffer[rptr];
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)    ffrvld <= 0;
    else if(ffrreq) ffrvld <= 1;
    else            ffrvld <= 0;
end

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)             ffvcnt <= 0;
    else if(ffwreq & ffrreq) ffvcnt <= ffvcnt;
    else if(ffwreq)          ffvcnt <= ffvcnt + 1; 
    else if(ffrreq)          ffvcnt <= ffvcnt - 1; 
end
endmodule: fifo