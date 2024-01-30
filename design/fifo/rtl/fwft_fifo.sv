/** First Word Fall Through Fifo */
module fwft_fifo #(parameter FD=8, DW=8)(
    input clk,
    input reset_n,
    output reg ffwfull,
    input ffwreq,
    input [DW-1:0] ffwdata,
    output ffrempty,
    input ffrreq,
    output reg [DW-1:0] ffrdata,
    output reg ffrvld,
    output reg [$clog2(FD):0] ffvcnt
);

/** Internal fifo signals */
wire intrnl_ffrempty;
wire intrnl_ffrreq;
wire [$clog2(FD-1):0] intrnl_ffvcnt;

assign ffvcnt = ffrvld ? (intrnl_ffvcnt + 1) : 0;
assign ffrempty = ffvcnt == 0;

assign intrnl_ffrreq = ~intrnl_ffrempty & (ffrreq | ~ffrvld);

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)              ffrvld <= 0;
    else if(intrnl_ffrreq)    ffrvld <= 1;
    else if(ffrvld & ~ffrreq) ffrvld <= 1;
    else                      ffrvld <= 0;
end

fifo #(.FD(FD-1), .DW(DW)) u_fifo(
    .clk
,   .reset_n
,   .ffwfull(ffwfull)
,   .ffwreq(ffwreq)
,   .ffwdata(ffwdata)
,   .ffrempty(intrnl_ffrempty)
,   .ffrreq(intrnl_ffrreq)
,   .ffrdata(ffrdata)
,   .ffrvld()
,   .ffvcnt(intrnl_ffvcnt)
);

endmodule: fwft_fifo