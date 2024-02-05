import re
import argparse
import pandas as pd
from pathlib import Path

md_rpt = """### Coverage
{coverage}

### Power
{power}

### Area
Gate Count: {gate_count}
"""

def parse_cov_rpt(rpt):
    log = re.findall(r'(Total Coverage Summary.*?)\n\n', cov_rpt, re.DOTALL)[0]
    log = log.split("\n")
    log_dict = dict(zip(log[1].strip().split(), log[2].strip().split()))
    return log_dict

def parse_area_rpt(rpt):
    log = re.findall(r'Total cell area:.*', rpt)[0]
    area = float(log.split()[-1])
    if re.search("sc6mcz", rpt):
        gate = area / 0.058
    else:
        raise NotImplementedError("Only 5nm process is available")
    return round(gate, 3)

def parse_pwr_rpt(rpt):
    log = re.findall(r'(Total Power.*?)\(', rpt)[0]
    return round(float(log.split("=")[-1].strip()) * 1000, 3)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-u", "--urg-rpt", action="store", type=str, required=True, help="URG Report Directory")
    parser.add_argument("-a", "--area-rpt", action="store", type=str, required=True, help="Area Report Directory")
    parser.add_argument("-p", "--pwr-rpt", action="store", type=str, required=True, help="Power Report Directory")
    args = parser.parse_args()

    cov_md = ""
    if Path(f"{args.urg_rpt}/dashboard.txt").is_file():
        cov_rpt = Path(f"{args.urg_rpt}/dashboard.txt").read_text()
        cov_rpt_dict = parse_cov_rpt(cov_rpt)
        cov_rpt_dict = {"Coverage(%)": cov_rpt_dict}
        cov_df = pd.DataFrame.from_dict(cov_rpt_dict).T
        cov_md = cov_df.to_markdown()
    gate = ""
    if Path(f"{args.area_rpt}/area.txt").is_file():
        area_rpt = Path(f"{args.area_rpt}/area.txt").read_text()
        gate = parse_area_rpt(area_rpt)
    pwr_md = ""
    if Path(f"{args.pwr_rpt}").is_dir():
        pwr_rpt_dict = {}
        for pwr_rpt in Path(f"{args.pwr_rpt}").glob("*.pwr"):
            pwr_rpt_dict[pwr_rpt.stem] = parse_pwr_rpt(pwr_rpt.read_text())
        pwr_rpt_dict = {"Power(mW)": pwr_rpt_dict}
        pwr_df = pd.DataFrame.from_dict(pwr_rpt_dict).T
        pwr_md = pwr_df.to_markdown()
    
    readme = md_rpt.format(
        coverage = cov_md,
        power = pwr_md,
        gate_count = gate
    )

    if Path("README.md").is_file():
        prev_readme = Path("README.md").read_text()
        pattern = r'(.*?)(?=### Coverage)'
        prev_readme = re.findall(pattern, prev_readme, re.DOTALL)[0].strip()
        readme = prev_readme + "\n" + readme
    Path("README.md").write_text(readme)