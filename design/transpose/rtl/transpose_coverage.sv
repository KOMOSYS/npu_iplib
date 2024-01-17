module transpose_coverage #(parameter AW=16)(
    input reset_n,
    input init_pulse,
    input repack_en,
    input [1:0] mode,
    input [AW-1:0] raddr_base,
    input [AW-1:0] waddr_base,
    input [AW-1:0] packed_dim_rsize,
    input [AW-1:0] unpacked_dim_wsize
);

covergroup cg_addr @(posedge init_pulse iff (reset_n));
    cp_raddr_nonzero : coverpoint raddr_base {
        bins nonzero = {[0:$]} with (item != 0);
    }
    cp_waddr_nonzero : coverpoint waddr_base {
        bins nonzero = {[0:$]} with (item != 0);
    }
endgroup: cg_addr

covergroup cg_shape @(posedge init_pulse iff (reset_n));
    option.cross_auto_bin_max = 0;
    
    cp_packed_size: coverpoint packed_dim_rsize {
        ignore_bins zero = {0};
        bins one = {1};
        bins small_size = {[2:63]};
        bins medium_size = {[64:127]};
        bins large_size =  {[128:$]};
        bins remainder_zero = {[2:$]} with ((item % 64) == 0);
        bins remainder_one = {[2:$]} with ((item % 64) == 1);
    }
    cp_unpacked_size: coverpoint unpacked_dim_wsize {
        ignore_bins zero = {0};
        bins one = {1};
        bins small_size = {[2:63]};
        bins medium_size = {[64:127]};
        bins large_size =  {[128:$]};
        bins remainder_zero = {[2:$]} with ((item % 64) == 0);
        bins remainder_one = {[2:$]} with ((item % 64) == 1);
    }
    cx_oneXone: cross cp_packed_size, cp_unpacked_size {
        bins oneXone = binsof(cp_packed_size.one) && binsof(cp_unpacked_size.one);
    }
endgroup: cg_shape

cg_addr u_cg_addr = new();
cg_shape u_cg_shape = new();

endmodule: transpose_coverage