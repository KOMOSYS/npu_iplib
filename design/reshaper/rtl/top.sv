module top #(parameter AW=16, DW=512, BUFFW=512*3, ADIM=6, MEM_DELAY=8)(
    input clk,
    input reset_n,
    input init_pulse,

    input [AW-1:0] rreq_num,
    input [AW-1:0] raddr_base,
    input [AW-1:0] raddr_size[ADIM],
    input [AW-1:0] raddr_stride[ADIM],
    input [AW-1:0] wreq_num,
    input [AW-1:0] waddr_base,
    input [AW-1:0] waddr_size[ADIM],
    input [AW-1:0] waddr_stride[ADIM],
    
    input [AW-1:0] rdata_size,
    input [AW-1:0] wdata_size,

    output reg [AW-1:0] raddr,
    output reg raddr_vld,
    input [DW-1:0] rdata,
    input rdata_vld,
    output reg [AW-1:0] waddr,
    output reg [DW-1:0] wdata,
    output reg wdata_vld,
    output reg finish
);

reshaper #(.AW(AW), .DW(DW), .BUFFW(BUFFW), .ADIM(ADIM), .MEM_DELAY(MEM_DELAY)) u_reshaper(.*);
//bind top.u_reshaper reshaper_assertion #(.AW(AW)) u_reshaper_assertion(
//    .clk
//,   .reset_n
//,   .init_pulse
//,   .rshpffrvld
//,   .rdffwfull(rd_fifo.ffwfull)
//,   .rdffwreq(rd_fifo.ffwreq)
//,   .rshpffwreq(rshp_fifo.ffwreq)
//,   .rreq_num
//,   .wreq_num
//,   .raddr_vld
//,   .rdata_vld
//,   .waddr_vld(waddr_gen.addr_vld)
//,   .wdata_vld
//,   .finish
//);
//bind top.u_reshaper reshaper_coverage #(.AW(AW), .DW(DW)) u_reshaper_coverage(.*);

endmodule: top