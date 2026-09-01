#!/usr/bin/env python3
"""Build inventory.txt from ssh_22.ini IPs + vCenter discovery CSV."""
from __future__ import annotations

import csv
import glob
import re
import sys
from pathlib import Path

BASE = Path("/home/tpx-admin/ansible/ssh_remediation")
SSH22 = Path("/home/tpx-admin/ansible/ssh_22.ini")
INVENTORY = BASE / "inventory.txt"
REPORTS = BASE / "reports"


def load_target_ips() -> list[str]:
    ips = []
    if SSH22.exists():
        for line in SSH22.read_text().splitlines():
            line = line.strip()
            if re.match(r"^\d+\.\d+\.\d+\.\d+$", line):
                ips.append(line)
    return ips


def latest_discovery_csv() -> Path | None:
    files = sorted(REPORTS.glob("ssh_status_*.csv"), key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0] if files else None


def main() -> int:
    target_ips = set(load_target_ips())
    if not target_ips:
        print("No target IPs found in ssh_22.ini", file=sys.stderr)
        return 1

    csv_path = latest_discovery_csv()
    vm_map: dict[str, dict] = {}
    if csv_path:
        with csv_path.open() as f:
            reader = csv.DictReader(f)
            for row in reader:
                ip = row.get("IP Address", "").strip()
                if ip in target_ips:
                    vm_map[ip] = row

    lines = [
        "# Auto-built from ssh_22.ini targets + discovery report",
        "# SSH remediation ONLY — unreachable hosts",
        "[ssh_unreachable]",
    ]

    for ip in sorted(target_ips):
        row = vm_map.get(ip, {})
        reachable = row.get("SSH Reachable", "")
        if reachable == "reachable":
            lines.append(f"# SKIP (SSH OK): {ip}")
            continue
        vm_name = row.get("VM Name", ip)
        vcenter = row.get("vCenter", "blr-vsphere-01.strykercorp.com")
        if reachable == "unreachable" or not row:
            lines.append(
                f"{ip} ansible_host={ip} vm_name={vm_name} vcenter={vcenter}"
            )
        elif reachable == "no_ip":
            lines.append(f"# NO IP in vCenter: {ip}")
        else:
            lines.append(f"# UNKNOWN status ({reachable}): {ip}")

    INVENTORY.write_text("\n".join(lines) + "\n")
    active = [l for l in lines if l.startswith(("10.", "172.", "192.")) or (not l.startswith("#") and "ansible_host" in l)]
    print(f"Wrote {INVENTORY} — {len([l for l in lines if 'ansible_host' in l])} hosts queued for remediation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
