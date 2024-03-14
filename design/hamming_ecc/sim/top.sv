module top #(parameter DW=10) (
	input           clk         ,
	input           reset_n     ,
        input           i_fifo_wreq ,
        input           i_fifo_rreq ,
        input  [DW-1:0] i_data      ,
        output          o_fifo_empty,     
        output          o_fifo_full ,     
        output [DW-1:0] o_data       
);

reg          r_o_data_monit  ;
wire         w_quit_cnt_start;
wire         w_quit_cnt_end  ;
reg          r_quit_cnt_flag ;
reg [   1:0] r_quit_cnt      ;

hamming_ecc #(.DW(DW)) u_hamming_ecc(
    .clk         ,
    .reset_n     ,
    .i_fifo_wreq ,
    .i_fifo_rreq ,
    .i_data      ,
    .o_fifo_empty,     
    .o_fifo_full ,     
    .o_data       
);

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n) r_o_data_monit <= '0;
    else         r_o_data_monit <= i_fifo_rreq;
end

assign w_quit_cnt_start = ~i_fifo_rreq & r_o_data_monit;
assign w_quit_cnt_end   = r_quit_cnt > 2'd2;

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n) r_quit_cnt_flag <= '0;
    else begin
        if      (w_quit_cnt_start) r_quit_cnt_flag <= 1'b1;
        else if (w_quit_cnt_end  ) r_quit_cnt_flag <= 1'b0;
    end
end

always_ff@(posedge clk or negedge reset_n) begin
    if(~reset_n) r_quit_cnt <= '0;
    else begin
        if      (r_quit_cnt_flag) r_quit_cnt <= r_quit_cnt + 'b1;
        else if (w_quit_cnt_end ) r_quit_cnt <= '0;
    end
end

endmodule: top
