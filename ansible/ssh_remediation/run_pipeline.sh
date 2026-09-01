#!/bin/bash
# Full SSH remediation pipeline for MissingCrowdStrike40.xlsx targets
# SSH-only changes — skips reachable hosts, serial=1 remediation
set -euo pipefail
cd "$(dirname "$0")"
export PYTHONPATH="/home/tpx-admin/.local/lib/python3.9/site-packages:${PYTHONPATH:-}"

EXCEL="${1:-MissingCrowdStrike40.xlsx}"
LOG="reports/pipeline_$(date +%Y%m%d_%H%M%S).log"
mkdir -p reports

exec > >(tee -a "$LOG") 2>&1

echo "=== SSH Remediation Pipeline ==="
echo "Started: $(date)"

if [ ! -f "$EXCEL" ]; then
  echo "ERROR: Excel not found: $EXCEL"
  echo "Upload from Windows:"
  echo "  scp C:\\Users\\ks4\\Downloads\\MissingCrowdStrike40.xlsx tpx-admin@10.90.105.221:/home/tpx-admin/ansible/ssh_remediation/"
  exit 1
fi

echo "--- Step 1: Import Excel to inventory ---"
python3 import_inventory.py "$EXCEL" -o inventory.draft.txt
echo "Review draft, copying to inventory.txt (approved targets only)"
cp inventory.draft.txt inventory.txt

echo "--- Step 2: Test vCenter via PowerCLI ---"
if ! ./connect_vsphere.sh; then
  echo "WARNING: vCenter connection failed — guest ops remediation may not work"
  echo "Continuing with SSH probe only..."
fi

echo "--- Step 3: Lookup VM names (if vCenter OK) ---"
ansible-playbook lookup_vm_names.yml || true

echo "--- Step 4: Probe SSH (read-only) ---"
ansible-playbook probe_inventory.yml

echo "--- Step 5: Build unreachable-only inventory ---"
python3 << 'PY'
import csv, re, subprocess
from pathlib import Path

base = Path("/home/tpx-admin/ansible/ssh_remediation")
probe_files = sorted(base.glob("reports/probe_*.csv"), key=lambda p: p.stat().st_mtime, reverse=True)
reachable = set()
if probe_files:
    with probe_files[0].open() as f:
        for row in csv.DictReader(f):
            if row.get("Status") == "reachable":
                reachable.add(row.get("IP", "").strip())

vm_map = {}
map_file = base / "reports" / "vm_name_map.csv"
if map_file.exists():
    with map_file.open() as f:
        for row in csv.DictReader(f):
            vm_map[row["IP"]] = (row["VM Name"], row["vCenter"])

draft = (base / "inventory.draft.txt").read_text().splitlines()
out = ["# Auto-built — unreachable hosts only", "[ssh_unreachable]"]
for line in draft:
    line = line.strip()
    if not line or line.startswith("#") or line.startswith("["):
        continue
    ip_m = re.search(r"ansible_host=(\d+\.\d+\.\d+\.\d+)", line)
    ip = ip_m.group(1) if ip_m else line.split()[0]
    if ip in reachable:
        out.append(f"# SKIP reachable: {ip}")
        continue
    if ip in vm_map:
        vm_name, vc = vm_map[ip]
        host = line.split()[0]
        out.append(f"{host} ansible_host={ip} vm_name={vm_name} vcenter={vc}")
    else:
        out.append(line)

(base / "inventory.txt").write_text("\n".join(out) + "\n")
active = sum(1 for l in out if "ansible_host" in l and not l.startswith("#"))
print(f"inventory.txt: {active} unreachable hosts queued")
PY

echo "--- Step 6: Remediate unreachable hosts (serial=1, SSH only) ---"
ansible-playbook remediate_ssh.yml

echo "=== Pipeline complete ==="
echo "Log: $LOG"
