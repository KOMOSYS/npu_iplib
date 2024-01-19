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
    BIT8_MODE = 2'b01,
    BIT32_MODE = 2'b10
} mode_t;

reg [BUFFD-1:0][7:0] buffer[BUFFD];

reg [$clog2(BUFFD)-1:0] wcnt;
reg [$clog2(BUFFD)-1:0] rcnt;

/** Write and Read buffer */
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)    for(int i=0; i<BUFFD; i++) for(int j=0; j<BUFFD; j++) buffer[i][j] <= 8'b0;
    else if(ffwreq) buffer[wcnt] <= ffwdata;
end
always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n)                           for(int i=0; i<BUFFD; i++) ffrdata[i] <= 8'b0;
    else if(ffrreq & (mode == BIT8_MODE))  for(int i=0; i<BUFFD; i++) ffrdata[i] <= buffer[i][rcnt];
    else if(ffrreq & (mode == BIT32_MODE)) for(int i=0; i<BUFFD; i++) ffrdata[i] <= buffer[i/4][rcnt*4+(i%4)];
end

/** Increase or decrease counter
* Wrap around counter if it reached limit
* For read counter, maximum count value differs with mode
*   For 8bit mode, maximum read count value is BUFFD
*   For 32bit mode, maxium read count value is BUFFD / 4, cause 32bit is 4byte
*/
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)    wcnt <= 0;
    else if(ffinit) wcnt <= 0;
	else if(ffwreq) wcnt <= (wcnt != BUFFD-1) ? (wcnt + 1) : 0;
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)                           rcnt <= 0;
    else if(ffinit)                        rcnt <= 0;
	else if(ffrreq & (mode == BIT8_MODE))  rcnt <= (rcnt != BUFFD-1) ? (rcnt + 1) : 0;
    else if(ffrreq & (mode == BIT32_MODE)) rcnt <= (rcnt != BUFFD/4-1) ? (rcnt + 1) : 0;
end
always_ff@(posedge clk or negedge reset_n) begin
	if(~reset_n)    ffrvld <= 0;
    else if(ffrreq) ffrvld <= 1;
	else            ffrvld <= 0;
end
endmodule: trp_fifo