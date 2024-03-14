module hamming_ecc #(parameter DW=10) (
	input           clk         ,
	input           reset_n     ,
        input           i_fifo_wreq ,
        input           i_fifo_rreq ,
        input  [DW-1:0] i_data      ,
        output          o_fifo_empty,     
        output          o_fifo_full ,     
        output [DW-1:0] o_data       
);

localparam PW = get_parity_width(DW);

// Parity Width Definition
function automatic int get_parity_width(input integer dw);
    int pw = 1;
    
    for(int i=0; i<DW; i++) begin
        if (2**pw >= pw + dw + 1) begin
            break;
        end
        else pw += 1;
    end
    return pw;
endfunction: get_parity_width 


wire [PW-1:0] w_parity1;
wire [PW-1:0] w_parity2;
wire [DW-1:0] w_data2  ;

hamming_enc #(.DW(DW), .PW(PW)) u_hamming_enc(
    .i_enc_data (i_data     ),
    .o_parity   (w_parity1  )
);

fifo #(.FC (1), .FD (2), .FW (DW)) u_data_fifo(
    .clk                   ,  // FIFO Clock
    .reset_n               ,  // FIFO Reset
    .ffbwreq (i_fifo_wreq ),  // FIFO Write Request
    .ffbrreq (i_fifo_rreq ),  // FIFO Read Request
    .ffbdi   (i_data      ),  // FIFO Data In
    .ffbempty(o_fifo_empty),  // FIFO Empty
    .ffbfull (o_fifo_full ),  // FIFO Full
    .ffbvcnt (            ),  // FIFO Valid Count
    .ffbdo   (w_data2     )   // FIFO Data Out
);

fifo #(.FC (1), .FD (2), .FW (PW)) u_parity_fifo(
    .clk                   ,  // FIFO Clock
    .reset_n               ,  // FIFO Reset
    .ffbwreq (i_fifo_wreq ),  // FIFO Write Request
    .ffbrreq (i_fifo_rreq ),  // FIFO Read Request
    .ffbdi   (w_parity1   ),  // FIFO Data In
    .ffbempty(            ),  // FIFO Empty
    .ffbfull (            ),  // FIFO Full
    .ffbvcnt (            ),  // FIFO Valid Count
    .ffbdo   (w_parity2   )   // FIFO Data Out
);

hamming_dec #(.DW(DW), .PW(PW)) u_hamming_dec(
    //.i_dec_data (),
    //.i_parity   (),
    .i_dec_data (w_data2  ),
    .i_parity   (w_parity2),
    .o_err_pos  (         ),
    .o_dec_data (o_data   )
);

endmodule: hamming_ecc
