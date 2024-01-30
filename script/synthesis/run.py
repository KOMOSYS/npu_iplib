import os, sys
import shutil
import argparse
from pathlib import Path
from contextlib import contextmanager

DC_PATH = "/tools/synopsys/syn/R-2020.09-SP4/bin/dc_shell"

@contextmanager
def chdir(dir):
    cur_dir = Path.cwd()
    try:
        os.chdir(dir)
        yield
    except:
        pass
    finally:
        os.chdir(cur_dir)

def list2tcllist(data):
    data = ' \\\n'.join(data)
    return f"[list \\\n{data}\n]"

def get_maxlib(process):
    if process == "5nm":
        return "sc6mcz_ln05lpe_base_rvt_c10_sspg_nominal_max_0p675v_m40c"
    else:
        raise NotImplementedError("Not supported process")

def get_maxop(process):
    if process == "5nm":
        return "sspg_nominal_max_0p675v_m40c"
    else:
        raise NotImplementedError("Not supported process")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--file_list", action="store", required=True, type=str, help="RTL file list file")
    parser.add_argument("-p", "--process", action="store", type=str, choices=["5nm"], default="5nm", help="Semiconductor fabrication")
    parser.add_argument("-s", "--sdc", action="store", required=True, type=str, help="Synopsys design constraint file")
    parser.add_argument("-t", "--top", action="store", required=True, type=str, help="Top module name")
    args = parser.parse_args()

    file_list_path = Path(args.file_list).resolve()
    sdc_path = Path(args.sdc).resolve()
    setup_tcl_path = Path(__file__).parent.resolve() / args.process / 'setup.tcl'
    run_tcl_path = Path(__file__).parent.resolve() / 'run.tcl'
    if not file_list_path.is_file():
        sys.exit("RTL file_list file does not exist")
    if not sdc_path.is_file():
        sys.exit("SDC file does not exist")
    if not setup_tcl_path.is_file():
        sys.exit(f"{args.process} setup file does not exist")
    if not run_tcl_path.is_file():
        sys.exit(f"Run tcl file does not exist")
    
    rtl_list =  []
    for rtl in file_list_path.read_text().strip().split("\n"):
        if "coverage" in rtl or "assertion" in rtl or "top.sv" in rtl:
            continue
        rtl_list.append(str(Path(file_list_path.parent) / rtl))

    run_tcl = run_tcl_path.read_text().format(
        setup_tcl=setup_tcl_path,
        sdc_file=sdc_path,
        top_name=args.top,
        rtl_file=list2tcllist(rtl_list),
        maxlib=get_maxlib(args.process),
        maxop=get_maxop(args.process),
    )

    if Path("tmp").is_dir():
        shutil.rmtree("tmp")
    Path("tmp").mkdir()
    with chdir("tmp"):
        Path("run.tcl").write_text(run_tcl)
        os.system(f"{DC_PATH} -f run.tcl")
        timing_rpt = Path("timing.txt").read_text()
        area_rpt = Path("area.txt").read_text()
    shutil.rmtree("tmp")
    if "No paths" not in timing_rpt:
        Path("timing.txt").write_text(timing_rpt)
    else:
        Path("area.txt").write_text(area_rpt)