import os, re, sys
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

def list2tcllist(data):
    data = ' \\\n'.join(data)
    return f"[list \\\n{data}\n]"

def get_condition_list(process):
    if process == "5nm":
        return ["tt_25c", "tt_85c", "tt_125c"]
    else:
        raise NotImplementedError("Not supported process")

def get_annotated_ratio(log):
    try:
        return float(re.findall(r"Nets.*", log)[0].split()[1].split("(")[1].split("%")[0])
    except:
        return 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--process", action="store", type=str, choices=["5nm"], default="5nm", help="Semiconductor fabrication")
    parser.add_argument("-t", "--top", action="store", required=True, type=str, help="Top module name")
    parser.add_argument("-T", "--top-hier", action="store", required=True, type=str, help="Top module hier path")
    parser.add_argument("-n", "--net", action="store", required=True, type=str, help="PreNet path")
    parser.add_argument("-s", "--saif", action="store", required=True, type=str, help="SAIF path")
    args = parser.parse_args()

    setup_tcl_path = Path(__file__).parent.resolve() / args.process / 'setup.tcl'
    run_tcl_path = Path(__file__).parent.resolve() / 'run.tcl'
    net_path = Path(args.net).resolve()
    saif_path = Path(args.saif).resolve()

    
    if not net_path.is_file():
        sys.exit("Pre net file does not exist")
    if not saif_path.is_file():
        sys.exit("SAIF file does not exist")
    if not setup_tcl_path.is_file():
        sys.exit(f"{args.process} setup file does not exist")
    if not run_tcl_path.is_file():
        sys.exit(f"Run tcl file does not exist")

    run_tcl = run_tcl_path.read_text().format(
        cond_list=list2tcllist(get_condition_list(args.process)),
        net_path=net_path,
        top_module=args.top,
        top_path=args.top_hier,
        saif_path=saif_path,
        setup_tcl=setup_tcl_path,
    )

    if Path("tmp").is_dir():
        shutil.rmtree("tmp")
    Path("tmp").mkdir()
    with chdir("tmp"):
        Path("run.tcl").write_text(run_tcl)
        os.system(f"{PTPX_PATH} -f run.tcl")

        if get_annotated_ratio(Path("not_annotated.txt").read_text()) > 99:
            for i in Path("./").glob("*pwr.txt"):
                shutil.copy(f"{str(i)}", f"../{str(i)}")
        else:
            shutil.copy("not_annotated.txt", "../not_annotated.txt")
    shutil.rmtree("tmp")
    