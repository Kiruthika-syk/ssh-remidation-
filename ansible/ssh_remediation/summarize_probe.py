#!/usr/bin/env python3
"""Build consolidated probe summary from probe_run.log"""
import re
from pathlib import Path

log = Path("reports/probe_run.log").read_text()
rows = []
for m in re.finditer(r'"msg": "([^:]+): (REACHABLE|UNREACHABLE)[^"]*"', log):
    host, status = m.group(1), m.group(2)
    action = "SKIPPED" if status == "REACHABLE" else "manual_console_or_fix_vcenter"
    rows.append((host, status.lower(), action))

out = Path("reports/excel_probe_summary.csv")
out.write_text("Host,SSH Status,Action\n" + "\n".join(f"{h},{s},{a}" for h,s,a in sorted(rows)) + "\n")
reachable = sum(1 for _,s,_ in rows if s == "reachable")
print(f"Summary: {len(rows)} hosts — {reachable} reachable (skipped), {len(rows)-reachable} unreachable")
print(f"Report: {out}")
