#!/bin/tclsh -f

#Create Session
new_project {top_name}.lint -f

#Design Setup
set_option sort yes 
set_option enableV05 yes
set_option enableSV09 yes
set_option inferblackbox yes
set_option mthresh 9128448 

read_file -type sourcelist {file_list}

set_option top {top_name}
set_option dw yes

{waive_module}

set_option sgsyn_loop_limit 16384
set_option allow_module_override yes
set_option define_cell_sim_depth 12
set_option enable_gateslib_autocompile yes
#Goal Setup
current_methodology {spyglass_home}/GuideWare/latest/block/rtl_handoff
set_option auto_save yes

current_goal lint/lint_rtl_enhanced     -top {top_name}

{set_goal}

{change_goal_severity}

{set_parameter}

{set_bbox}

run_goal

save_project
exit -force