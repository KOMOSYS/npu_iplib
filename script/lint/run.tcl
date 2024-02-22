#!/bin/tclsh -f
set top_name {top_name}
set file_list {file_list}
set gate_lib {gate_lib}
set spyglass_home {spyglass_home}

new_project $top_name.lint -f

set_option sort yes 
set_option enableV05 yes
set_option enableSV09 yes
set_option mthresh 9128448 
set_option sgsyn_loop_limit 16384

read_file -type sourcelist $file_list
read_file -type gateslib $gate_lib

compile_design

set_option top $top_name
set_option dw yes
set_option allow_module_override yes
set_option define_cell_sim_depth 12
set_option enable_gateslib_autocompile yes

current_methodology $spyglass_home/GuideWare/latest/block/rtl_handoff
set_option auto_save yes

current_goal lint/lint_rtl -top $top_name
set_goal_option addrule       W18
set_goal_option addrule       W123
set_goal_option addrule       W164a
set_goal_option addrule       W164b
set_goal_option addrule       W164c
set_goal_option addrule       W287a
set_goal_option addrule       W336
set_goal_option addrule       W415
set_goal_option addrule       W339a

set_goal_option overloadrules W164c+severity=Error
set_goal_option overloadrules W164a+severity=Error
set_goal_option overloadrules W224+severity=Error
set_goal_option overloadrules W287a+severity=Error
set_goal_option overloadrules W287b+severity=Error
set_goal_option overloadrules W287c+severity=Error
set_goal_option overloadrules W339a+severity=Error

set_parameter checkfullbus    yes
set_parameter checkfullrecord yes
set_parameter handle_large_bus yes

run_goal
save_project
exit -force