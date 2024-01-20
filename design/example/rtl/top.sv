module top(
    input clk,
    input reset_n
);

example u_example(.*);
bind top.u_example example_coverage u_example_coverage(.*);
bind top.u_example example_assertion u_example_assertion(.*);

endmodule: top