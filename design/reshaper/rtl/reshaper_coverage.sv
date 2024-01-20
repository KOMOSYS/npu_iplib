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
    cp_rsize: coverpoint rdata_size {
        ignore_bins zero = {0};
        bins one = {1};
        bins small_size = {[2:$]} with (item*8 < DW);
        bins big_size = {[2:$]} with (item*8 >= DW);
    }
    cp_wsize: coverpoint wdata_size {
        ignore_bins zero = {0};
        bins one = {1};
        bins small_size = {[2:$]} with (item*8 < DW);
        bins big_size = {[2:$]} with (item*8 >= DW);
    }
    cx_rwsize: cross cp_rsize, cp_wsize {
        ignore_bins oneXone = binsof(cp_rsize.one) && binsof(cp_wsize.one);
    }
    cp_scale: coverpoint upscale;
endgroup: cg_reshape

cg_addr u_cg_addr = new();
cg_reshape u_cg_reshape = new();

endmodule: reshaper_coverage