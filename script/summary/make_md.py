import re
import argparse
import pandas as pd
from pathlib import Path

md_rpt = """### Coverage
{coverage}

### Power
{power}

### Area
{area}
"""

def parse_cov_rpt(rpt):
    log = re.findall(r'(Total Coverage Summary.*?)\n\n', cov_rpt, re.DOTALL)[0]
    log = log.split("\n")
    log_dict = dict(zip(log[1].strip().split(), log[2].strip().split()))
    return log_dict

def parse_area_rpt(rpt):
    log = re.findall(r'Total cell area:.*', rpt)[0]
    return round(float(log.split()[-1]), 3)

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
    area_md = ""
    if Path(args.area_rpt).is_dir():
        area_rpt_dict = {}
        for i in list(Path(args.area_rpt).glob("*")):
            if (not i.is_dir()) or (not (i / "area.txt").is_file()):
                continue
            area_rpt = (i / "area.txt").read_text()
            area_rpt_dict[i.name] = parse_area_rpt(area_rpt)
        if area_rpt_dict:
            area_rpt_dict = {"Area(um^2)": area_rpt_dict}
            area_df = pd.DataFrame(area_rpt_dict).T
            area_md = area_df.to_markdown()

    pwr_md = ""
    if Path(args.pwr_rpt).is_dir():
        pwr_rpt_dict = {}
        for i in list(Path(args.pwr_rpt).glob("*")):
            if (not i.is_dir()) or (not list(i.glob("*.pwr"))):
                continue
            for pwr_rpt in sorted(i.glob("*.pwr"), key=lambda x: int(x.stem.split("_")[-1][:-1].replace("m", "-"))):
                pwr_rpt_dict[(i.name, pwr_rpt.stem)] = parse_pwr_rpt(pwr_rpt.read_text())

        if pwr_rpt_dict:
            columns = list(pwr_rpt_dict.keys())
            pwr_rpt_dict = {"Power(mW)": pwr_rpt_dict}
            pwr_df = pd.DataFrame(pwr_rpt_dict).T
            pwr_df = pwr_df[columns]
            pwr_md = pwr_df.to_html()

    readme = md_rpt.format(
        coverage = cov_md,
        power = pwr_md,
        area = area_md
    )

    if Path("README.md").is_file():
        prev_readme = Path("README.md").read_text()
        pattern = r'(.*?)(?=### Coverage)'
        prev_readme = re.findall(pattern, prev_readme, re.DOTALL)[0].strip()
        readme = prev_readme + "\n" + readme
    Path("README.md").write_text(readme)