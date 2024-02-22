import os, sys, re
import shutil
import argparse
from pathlib import Path
from contextlib import contextmanager

LM_LICENSE_FILE = "27020@deepx02:27020@deepx03"
SPYGLASS_HOME = "/tools/synopsys/spyglass/U-2023.03/SPYGLASS_HOME/"
GATE_LIB = "/DKIT/ARM_5LPE/STD_CELL/ln05lpe/LIB/sc6mcz_ln05lpe_base_rvt_c10_sspg_nominal_max_0p675v_m40c.lib"

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
        gate_lib=GATE_LIB,
        spyglass_home=SPYGLASS_HOME
    )
    Path("run.tcl").write_text(run_tcl)
    set_env()
    os.system(f"sg_shell -tcl run.tcl")