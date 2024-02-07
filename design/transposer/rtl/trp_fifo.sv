module trp_fifo #(parameter BUFFD=64)(
    input clk,
    input reset_n,
    input [1:0] mode,
    input ffinit,
    input ffwreq,
    input ffrreq,
    input [BUFFD-1:0][7:0] ffwdata,
    output reg [BUFFD-1:0][7:0] ffrdata,
    output reg ffrvld
);

typedef enum logic [1:0] {
    BIT8_MODE  = 2'b01,
    BIT32_MODE = 2'b10
} mode_t;

reg [BUFFD-1:0][7:0] buffer[BUFFD];

reg [$clog2(BUFFD)-1:0] wptr;
reg [$clog2(BUFFD)-1:0] rptr;

/** Write and Read buffer */
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)    for(int i=0; i<BUFFD; i++) for(int j=0; j<BUFFD; j++) buffer[i][j] <= 8'b0;
    else if(ffwreq) buffer[wptr] <= ffwdata;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                           for(int i=0; i<BUFFD; i++) ffrdata[i] <= 8'b0;
    else if(ffrreq & (mode == BIT8_MODE))  for(int i=0; i<BUFFD; i++) ffrdata[i] <= buffer[i][rptr];
    else if(ffrreq & (mode == BIT32_MODE)) for(int i=0; i<BUFFD; i++) ffrdata[i] <= buffer[i/4][rptr*4+(i%4)];
end

always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)    wptr <= 0;
    else if(ffinit) wptr <= 0;
	else if(ffwreq) wptr <= wptr + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)    rptr <= 0;
    else if(ffinit) rptr <= 0;
    else if(ffrreq) rptr <= rptr + 1;
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)    ffrvld <= 0;
    else if(ffrreq) ffrvld <= 1;
	else            ffrvld <= 0;
end
endmodule: trp_fifo