module reshaper_coverage #(parameter AW=16, DW=512)(
    input reset_n,
    input init_pulse,
    input [AW-1:0] raddr_base,
    input [AW-1:0] waddr_base,
    input [AW-1:0] rdata_size,
    input [AW-1:0] wdata_size
);

wire upscale;

covergroup cg_addr @(posedge init_pulse iff (reset_n));
    cp_raddr_nonzero : coverpoint raddr_base {
        bins nonzero = {[0:$]} with (item != 0);
    }
    cp_waddr_nonzero : coverpoint waddr_base {
        bins nonzero = {[0:$]} with (item != 0);
    }
endgroup: cg_addr

assign upscale = rdata_size < wdata_size;
covergroup cg_reshape @(posedge init_pulse iff (reset_n));
    option.cross_auto_bin_max = 0;

    cp_rsize: coverpoint rdata_size {
        ignore_bins zero = {0};
        bins one = {1};
        bins small_size = {[2:(DW/8)-1]};
        bins medium_size = {[(DW/8):(DW/8)*2-1]};
        bins large_size =  {[(DW/8)*2:$]};
        bins remainder_zero = {[2:$]} with ((item % (DW/8)) == 0);
        bins remainder_one = {[2:$]} with ((item % (DW/8)) == 1);
    }
    cp_wsize: coverpoint wdata_size {
        ignore_bins zero = {0};
        bins one = {1};
        bins small_size = {[2:(DW/8)-1]};
        bins medium_size = {[(DW/8):(DW/8)*2-1]};
        bins large_size =  {[(DW/8)*2:$]};
        bins remainder_zero = {[2:$]} with ((item % (DW/8)) == 0);
        bins remainder_one = {[2:$]} with ((item % (DW/8)) == 1);
    }
    cx_rwsize: cross cp_rsize, cp_wsize {
        bins oneXnotone = binsof(cp_rsize.one) && (!binsof(cp_wsize.one));
        bins notoneXone = (!binsof(cp_rsize.one)) && binsof(cp_wsize.one);
    }
    cp_scale: coverpoint upscale;
endgroup: cg_reshape

cg_addr u_cg_addr = new();
cg_reshape u_cg_reshape = new();

endmodule: reshaper_coverage