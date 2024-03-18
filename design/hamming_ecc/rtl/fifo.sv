module fifo
#(
    parameter FC  = 1,             // FC : FIFO Counter Bits
    parameter FD  = 2,             // FD : FIFO Depth
    parameter FW  = 512,           // FW : FIFO Width
    parameter FDH = FD - 1,
    parameter FWH = FW - 1,
    parameter FCH = FC - 1
)(
    input              clk     ,  // FIFO Clock
    input              reset_n ,  // FIFO Reset
    input              ffbwreq ,  // FIFO Write Request
    input              ffbrreq ,  // FIFO Read Request
    input      [FWH:0] ffbdi   ,  // FIFO Data In
    output             ffbempty,  // FIFO Empty
    output             ffbfull ,  // FIFO Full
    output     [ FC:0] ffbvcnt ,  // FIFO Valid Count
    output reg [FWH:0] ffbdo      // FIFO Data Out
);
//------------------------------------------------------------------------------
// Signals for FIFO Entry
//------------------------------------------------------------------------------
wire        incwcnt;  // Increase Write Counter
wire        incrcnt;  // Increase Read Counter
reg [FCH:0] wcnt   ;  // Write Counter
reg [FCH:0] rcnt   ;  // Read Counter
reg [ FC:0] vcnt   ;  // FIFO Valid Entry Count
//------------------------------------------------------------------------------
// Decoded Write/Read Counter
//------------------------------------------------------------------------------
assign ffbempty = (vcnt == 0)          ;
assign ffbfull  = (vcnt >= FD)         ;
assign incwcnt  = (ffbwreq & ~ffbfull) ;
assign incrcnt  = (ffbrreq & ~ffbempty);
assign ffbvcnt  = vcnt                 ;

always @(posedge clk or negedge reset_n)
begin
  if      (~reset_n) wcnt <= 0;
  else if (incwcnt)  wcnt <= (wcnt != FDH) ? (wcnt + 1) : 0;
end

always @(posedge clk or negedge reset_n)
begin
  if      (~reset_n) rcnt <= 0;
  else if (incrcnt)  rcnt <= (rcnt != FDH) ? (rcnt + 1) : 0;
end

always @(posedge clk or negedge reset_n)
begin
  if     (~reset_n)          vcnt <= 0          ;
  else if(incrcnt & incwcnt) vcnt <= vcnt       ;
  else if(incwcnt)           vcnt <= vcnt + 1'b1;
  else if(incrcnt)           vcnt <= vcnt - 1'b1;
end

//------------------------------------------------------------------------------
// FIFO Write / Read (no delay)
//------------------------------------------------------------------------------
reg [FWH:0] mb [0:FDH];

always @(posedge clk) begin
  if (incwcnt) mb[wcnt] <= ffbdi;  // Write
end
//assign ffbdo = mb[rcnt]; // Read
//reg [FWH:0] ffbdo;      // FIFO Data Out

always @(posedge clk or negedge reset_n)
begin
  if      (~reset_n) ffbdo <= 0       ;
  else if (incrcnt)  ffbdo <= mb[rcnt];
end
//------------------------------------------------------------------------------
// Assertion
//------------------------------------------------------------------------------
property fullwrite;
  @(posedge clk) disable iff(~reset_n) ffbwreq |-> ~ffbfull;
endproperty: fullwrite

property emptyread;
  @(posedge clk) disable iff(~reset_n) ffbrreq |-> ~ffbempty;
endproperty: emptyread

fifo_fullwrite:
assert property(fullwrite) else $warning("Fifo Full Write Occurs");

fifo_emptyread:
assert property(emptyread) else $warning("Fifo Empty Read Occurs");

endmodule
