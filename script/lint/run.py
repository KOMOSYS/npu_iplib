import os, sys, re
import shutil
import argparse
from pathlib import Path
from contextlib import contextmanager

LM_LICENSE_FILE = "27020@deepx02:27020@deepx03"
SPYGLASS_HOME = "/tools/synopsys/spyglass/U-2023.03/SPYGLASS_HOME/"
GATE_LIB = "/DKIT/ARM_5LPE/STD_CELL/ln05lpe/LIB/sc6mcz_ln05lpe_base_rvt_c10_sspg_nominal_max_0p675v_m40c.lib"

def set_bbox():
    set_bbox = ""
    bbox_list = [
    "rf_sp_hse_640x96m2b2s2w0p0d1v0t0r1200c1a1", 
    "rf_sp_hse_128x96m2b1s2w0p0d1v0t0r1200c1a1", 
    "rf_sp_hse_1024x128m2b2s2w0p0d1v1t0r1200c1a1", 
    "clk_buf_6t", 
    "clk_gate_6t"]
    for bbox in bbox_list:
        set_bbox += f"set_option stop {bbox}\n"
    return set_bbox

def set_parameter():
    set_parameter = ""
    parameter_list = ["checkfullbus", "checkfullrecord", "handle_large_bus"]
    for parameter in parameter_list:
        set_parameter += f"set_parameter {parameter} yes\n"
    return set_parameter

def change_goal_severity():
    change_goal_severity = ""
    Info_goal_list = ["W111", "W240", "w498", "W287b"]
    for goal in Info_goal_list:
        change_goal_severity += f"set_goal_option overloadrules {goal}+severity=Info\n"

    warn_goal_list = ["STARC-2.3.4.3"]
    for goal in warn_goal_list:
        change_goal_severity += f"set_goal_option overloadrules {goal}+severity=Warning\n"

    error_goal_list = ["W164c", "W164a", "W224", "W287a", "W287c", "W339a"]
    for goal in error_goal_list:
        change_goal_severity += f"set_goal_option overloadrules {goal}+severity=Error\n"
    
    return change_goal_severity

def set_goal():
    set_goal = ""
    goal_list = [
    "W18", "W123", "W164a", "W164b", "W164c", "W287a", "W336", "W415", "W339a",
    "W111", "W488", "W69", "W71", "W263", "W392", "W448", "W391", "W401", "W120", 
    "W121", "W494a", "W494b", "W497", "W498", "W541", "W19", "W414", "W484", "W110", 
    "W156", "W116", "W362", "W486", "W415", "W552", "W553", "W352", "W479", "W480", 
    "W481a", "W481b", "W287b"]
    for goal in goal_list:
        set_goal += f"set_goal_option addrule {goal}\n"
    return set_goal

def waive_module():
    waive_module = ""
    for module in ["DW01_cmp2", "DW_fp_flt2i"]:
        waive_module += f"waive -msg {{Design Unit '{module}'   has empty definition}}  -rule {{  {{WarnAnalyzeBBox}}  }}\n"
    return waive_module


def set_env():
    os.environ["LM_LICENSE_FILE"] = "27020@deepx02:27020@deepx03"
    os.environ["PATH"] = f'{os.getenv("PATH")}:{SPYGLASS_HOME}/bin'

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--top", action="store", required=True, type=str, help="Top module name")
    parser.add_argument("-f", "--file_list", action="store", required=True, type=str, help="RTL file list file")
    args = parser.parse_args()

    file_list_path = Path(args.file_list).resolve()
    run_tcl_path = Path(__file__).parent.resolve() / 'run.tcl'
    if not file_list_path.is_file():
        sys.exit("RTL file_list file does not exist")
    if not run_tcl_path.is_file():
        sys.exit(f"Run tcl file does not exist")

    file_list_lint = Path(file_list_path).read_text()
    for pattern in ["top.sv", ".*coverage.*", ".*assertion.*"]:
        file_list_lint = re.sub(pattern, "", file_list_lint)
    Path("./file_list_lint.f").write_text(file_list_lint)

    run_tcl = run_tcl_path.read_text().format(
        top_name=args.top,
        file_list="./file_list_lint.f",
        spyglass_home=SPYGLASS_HOME,
        waive_module=waive_module(),
        set_goal=set_goal(),
        change_goal_severity=change_goal_severity(),
        set_parameter=set_parameter(),
        set_bbox=set_bbox()
    )
    Path("run.tcl").write_text(run_tcl)
    set_env()
    os.system(f"sg_shell -tcl run.tcl")