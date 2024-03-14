module hamming_dec 
#(
    parameter DW=8,
    parameter PW=4
)(
    input  [DW-1:0] i_dec_data,
    input  [PW-1:0] i_parity  ,
    output [PW-1:0] o_err_pos ,
    output [DW-1:0] o_dec_data   
);

localparam TW = DW + PW;

//--------------------------------------
// Predefined Data Position
//--------------------------------------
typedef int data_pos_t [DW];
function automatic data_pos_t get_data_pos();
    int data_pos_idx = '0;
    for(int i=1; i<TW+1; i++) begin
        if(!((1 << $clog2(i)) == i)) begin
            get_data_pos[data_pos_idx] = i;
            data_pos_idx++;
        end
    end
    return get_data_pos;
endfunction: get_data_pos
localparam int data_pos [DW] = get_data_pos();

//--------------------------------------
// Main Body
//--------------------------------------
// Check Bit Generation
logic [PW-1:0] r_chk_bit;

always_comb begin
    r_chk_bit = '0;
    foreach(r_chk_bit[i]) begin
        foreach(data_pos[j]) begin
            if (data_pos[j][i]) begin
                r_chk_bit[i] ^= i_dec_data[j];
            end
        end
        r_chk_bit[i] ^= i_parity[i];
    end
end

assign o_err_pos = r_chk_bit;

// Error Correction
logic err_bit_enable;
reg [PW-1:0] err_bit = '0;

always_comb begin
    err_bit = '0;
    err_bit_enable = '0;
    foreach(data_pos[i]) begin
        if(data_pos[i][PW-1:0] == o_err_pos) begin
            err_bit = i;
            err_bit_enable = 1;
        end
    end
end

assign o_dec_data = err_bit_enable ? i_dec_data ^ (1 << err_bit) : i_dec_data;

endmodule: hamming_dec
