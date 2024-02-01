import os, sys
import shutil
import argparse
from pathlib import Path
from contextlib import contextmanager

PTPX_PATH = "/tools/synopsys/prime/S-2021.06-SP5/bin/pt_shell"

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

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--condition", action="store", type=str, choices=["tt_25c", "tt_85c", "tt_125c"], default="tt_25c", help="Voltage and Temperature")
    parser.add_argument("-p", "--process", action="store", type=str, choices=["5nm"], default="5nm", help="Semiconductor fabrication")
    parser.add_argument("-t", "--top", action="store", required=True, type=str, help="Top module name")
    parser.add_argument("-T", "--top-hier", action="store", required=True, type=str, help="Top module hier path")
    parser.add_argument("-n", "--net", action="store", required=True, type=str, help="PreNet path")
    parser.add_argument("-f", "--fsdb", action="store", required=True, type=str, help="FSDB path")
    args = parser.parse_args()

    setup_tcl_path = Path(__file__).parent.resolve() / args.process / 'setup.tcl'
    run_tcl_path = Path(__file__).parent.resolve() / 'run.tcl'
    net_path = Path(args.net).resolve()
    fsdb_path = Path(args.fsdb).resolve()

    
    if not net_path.is_file():
        sys.exit("Pre net file does not exist")
    if not fsdb_path.is_file():
        sys.exit("FSDB file does not exist")
    if not setup_tcl_path.is_file():
        sys.exit(f"{args.process} setup file does not exist")
    if not run_tcl_path.is_file():
        sys.exit(f"Run tcl file does not exist")

    run_tcl = run_tcl_path.read_text().format(
        cond=args.condition,
        net_path=net_path,
        top_module=args.top,
        top_path=args.top_hier,
        fsdb_path=fsdb_path,
        setup_tcl=setup_tcl_path,
    )

    if Path("tmp").is_dir():
        shutil.rmtree("tmp")
    Path("tmp").mkdir()
    with chdir("tmp"):
        Path("run.tcl").write_text(run_tcl)
        os.system(f"{PTPX_PATH} -f run.tcl")
    #    if "No paths" not in Path("timing.txt").read_text():
    #        shutil.copy("timing.txt", "../timing.txt")
    #    else:
    #        shutil.copy("area.txt", "../area.txt")
    #        shutil.copy(f"{args.top}.v", f"../{args.top}.v")
    #shutil.rmtree("tmp")
    