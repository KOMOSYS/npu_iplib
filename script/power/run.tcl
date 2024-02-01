set cond {cond}
set net_path {net_path}
set top_module {top_module}
set top_path {top_path}
set fsdb_path {fsdb_path}
source {setup_tcl}

set_host_options -num_processes 4 -max_cores 4
read_verilog $net_path
link $top_module
set power_enable_analysis true
set power_analysis_mode time_based
read_fsdb -strip_path $top_path $fsdb_path
check_power
update_power
report_power > [string cat $cond ".pwr.txt"]
report_switching_activity -list_not_annotated > not_annotated.txt
exit