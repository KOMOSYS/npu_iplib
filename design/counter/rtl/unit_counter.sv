module unit_counter#(parameter BW=16) (
    input clk,
    input reset_n,
    input inc_cnt,
    input clr_cnt,
    output reg [BW-1:0] cnt
);

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)     cnt <= 0;
    else if(clr_cnt) cnt <= 0;
    else if(inc_cnt) cnt <= cnt + 1;
end

endmodule: unit_counter