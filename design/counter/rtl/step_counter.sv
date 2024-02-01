module step_counter#(parameter BW=16) (
    input clk,
    input reset_n,
    input inc_cnt,
    input clr_cnt,
    input [BW-1:0] cnt_step,
    output reg [BW-1:0] cnt
);

always_ff@(posedge clk or negedge reset_n) begin 
    if(~reset_n)     cnt <= 0;
    else if(clr_cnt) cnt <= 0;
    else if(inc_cnt) cnt <= cnt + cnt_step;
end

endmodule: step_counter