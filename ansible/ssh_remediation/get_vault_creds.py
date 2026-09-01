#!/usr/bin/env python3
"""Extract vCenter credentials from encrypted vault (stdout JSON, no logging)."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

VAULT = Path(__file__).resolve().parent / "vault.yml"
PASS = Path(__file__).resolve().parent.parent / "linux_tanium" / "vault_password_file"


def main() -> int:
    if not VAULT.exists() or not PASS.exists():
        print(json.dumps({"error": "vault or password file missing"}))
        return 1
    result = subprocess.run(
        ["ansible-vault", "view", str(VAULT), "--vault-password-file", str(PASS)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print(json.dumps({"error": "vault decrypt failed"}))
        return 1
    try:
        import yaml
    except ImportError:
        print(json.dumps({"error": "pyyaml not installed"}))
        return 1
    data = yaml.safe_load(result.stdout) or {}
    out = {
        "vcenter_username": data.get("vcenter_username", ""),
        "vcenter_password": data.get("vcenter_password", ""),
        "guest_username": (data.get("guest_credentials") or {}).get("username", "root"),
        "guest_password": (data.get("guest_credentials") or {}).get("password", ""),
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
