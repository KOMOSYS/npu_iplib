source {setup_tcl}
set top_name {top_name}
set rtl_file {rtl_file}
set maxlib {maxlib}
set maxop {maxop}

set_host_options -max_cores 8
analyze -vcs -sverilog $rtl_file
elaborate $top_name
source {sdc_file}
set_operating_conditions -max_library $maxlib -max $maxop
check_design
check_timing
compile_ultra -no_autoungroup -no_seq_output_inversion -no_boundary_optimization -gate_clock 
compile_ultra -incremental -no_autoungroup -no_seq_output_inversion -no_boundary_optimization -gate_clock
report_timing -nosplit -slack_lesser_than 0 -max 100 > timing.txt
report_area > area.txt
write -f verilog -hierarchy -o [string cat $top_name ".v"]
exit