module hamming_enc
#(
    parameter DW = 10,
    parameter PW = 4
)(
    input  [DW-1:0] i_enc_data,
    output [PW-1:0] o_parity  
);

localparam TW = DW + PW;

//--------------------------------------
// Predefined Data Position
//--------------------------------------
typedef int data_pos_t [DW];
function automatic data_pos_t get_data_pos();
    int data_pos_idx = '0;
    for(int i=0; i<TW; i++) begin
        if(!((1 << $clog2(i+1)) == (i+1))) begin
            get_data_pos[data_pos_idx] = i+1;
            data_pos_idx++;
        end
    end
    return get_data_pos;
endfunction: get_data_pos
localparam int data_pos [DW] = get_data_pos();

//--------------------------------------
// Main Body
//--------------------------------------
logic [PW-1:0] r_parity;

always_comb begin
    r_parity = '0;
    foreach(r_parity[i]) begin
        foreach(data_pos[j]) begin
            if(data_pos[j][i]) begin
                r_parity[i] ^= i_enc_data[j];
            end
        end
    end
end

assign o_parity = r_parity;
endmodule: hamming_enc
