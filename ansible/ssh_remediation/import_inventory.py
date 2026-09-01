#!/usr/bin/env python3
"""Parse MissingCrowdStrike Excel into Ansible inventory."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import openpyxl
except ImportError:
    print("ERROR: openpyxl not installed. Run: pip3 install --user openpyxl", file=sys.stderr)
    sys.exit(1)

HOSTNAME_COLS = ("hostname", "host name", "server", "vm name", "vm_name", "computer name")
IP_COLS = (
    "ip_address_nix",
    "ip address_nix",
    "ip_address",
    "ip address",
    "ip",
    "address",
)
VCENTER_COLS = ("vcenter", "vcentre", "vc")
DEFAULT_VCENTER = "blr-vsphere-01.strykercorp.com"
IP_RE = re.compile(r"\b(\d{1,3}(?:\.\d{1,3}){3})\b")


def normalize_header(value) -> str:
    if value is None:
        return ""
    return re.sub(r"\s+", " ", str(value).strip().lower())


def find_column(headers: list[str], candidates: tuple[str, ...]) -> int | None:
    for idx, header in enumerate(headers):
        if header in candidates:
            return idx
        for candidate in candidates:
            if candidate.replace("_", " ") in header or candidate in header:
                return idx
    return None


def first_ip(value) -> str:
    if value is None:
        return ""
    text = str(value).strip()
    if not text or text.lower() in ("nan", "none", "n/a"):
        return ""
    match = IP_RE.search(text)
    return match.group(1) if match else ""


def valid_hostname(name: str) -> bool:
    if not name or len(name) < 2:
        return False
    if name.endswith("_") or name.startswith("_"):
        return False
    return bool(re.match(r"^[a-zA-Z0-9][a-zA-Z0-9._-]+$", name))


def parse_excel(path: Path) -> list[dict]:
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    rows: list[dict] = []

    for sheet in wb.worksheets:
        data = sheet.iter_rows(values_only=True)
        try:
            raw_headers = next(data)
        except StopIteration:
            continue

        headers = [normalize_header(h) for h in raw_headers]
        host_col = find_column(headers, HOSTNAME_COLS)
        ip_col = find_column(headers, IP_COLS)
        vc_col = find_column(headers, VCENTER_COLS)

        if host_col is None:
            continue

        for row in data:
            if not row:
                continue
            hostname = str(row[host_col]).strip() if row[host_col] else ""
            if not valid_hostname(hostname):
                continue

            ip = ""
            if ip_col is not None and row[ip_col]:
                ip = first_ip(row[ip_col])
            if not ip:
                for idx, cell in enumerate(row):
                    if idx == host_col:
                        continue
                    ip = first_ip(cell)
                    if ip:
                        break
            if not ip:
                continue

            vcenter = str(row[vc_col]).strip() if vc_col is not None and row[vc_col] else DEFAULT_VCENTER
            rows.append({"hostname": hostname, "ip": ip, "vcenter": vcenter, "sheet": sheet.title})

    wb.close()
    return rows


def render_inventory(entries: list[dict]) -> str:
    lines = [
        "# From MissingCrowdStrike Excel — SSH remediation targets",
        "[ssh_unreachable]",
    ]
    seen: set[str] = set()
    for entry in entries:
        host = entry["hostname"]
        if host in seen:
            continue
        seen.add(host)
        lines.append(
            f"{host} ansible_host={entry['ip']} vm_name={host} vcenter={entry['vcenter']}"
        )

    if len(lines) == 2:
        lines.append("# No valid hosts parsed")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Import Excel host list to inventory")
    parser.add_argument("excel_file", type=Path)
    parser.add_argument("--output", "-o", type=Path, default=Path("inventory.draft.txt"))
    parser.add_argument("--apply", action="store_true", help="Also copy to inventory.txt")
    args = parser.parse_args()

    if not args.excel_file.exists():
        print(f"ERROR: File not found: {args.excel_file}", file=sys.stderr)
        return 1

    entries = parse_excel(args.excel_file)
    output = render_inventory(entries)
    args.output.write_text(output)
    if args.apply:
        Path("inventory.txt").write_text(output)
    print(f"Parsed {len(entries)} hosts -> {args.output}")
    if args.apply:
        print("Applied to inventory.txt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
