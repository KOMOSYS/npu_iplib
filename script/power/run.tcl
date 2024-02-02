set cond_list {cond_list}
set net_path {net_path}
set top_module {top_module}
set top_path {top_path}
set sdc_file {sdc_file}
set saif_path {saif_path}

set_host_options -num_processes 4 -max_cores 4
set power_enable_analysis true
set power_analysis_mode averaged

foreach i $cond_list {{
    set cond $i
    source {setup_tcl}
    read_verilog $net_path
    link $top_module
    read_sdc $sdc_file
    read_saif -strip_path $top_path $saif_path
    check_power
    update_power
    report_power > [string cat $cond ".pwr.txt"]
    report_switching_activity -list_not_annotated > not_annotated.txt
    remove_design -all
}}
exit