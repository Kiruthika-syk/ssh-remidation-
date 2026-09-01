#!/bin/bash
# Wrapper: connect to all vSphere vCenters via PowerCLI using vault credentials
set -euo pipefail
cd "$(dirname "$0")"
export PYTHONPATH="/home/tpx-admin/.local/lib/python3.9/site-packages:${PYTHONPATH:-}"
exec pwsh -NoProfile -File ./connect_vsphere.ps1 "$@"
