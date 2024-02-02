set clk_derate 0.6
set clk_trans  0.1625
set clk_freq   1000
set clk_period [expr [expr 1000.0 / $clk_freq] * $clk_derate]
set clk_port   clk
create_clock -period $clk_period [get_ports $clk_port]
set_clock_uncertainty -setup [expr {$clk_period * 0.03}] [get_clocks $clk_port]
set_clock_transition $clk_trans [all_clocks]