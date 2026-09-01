#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
VAULT_PASS="../linux_tanium/vault_password_file"

if [ ! -f "$VAULT_PASS" ]; then
  echo "ERROR: Vault password file not found: $VAULT_PASS"
  exit 1
fi

if [ -f vault.yml ] && ansible-vault view vault.yml --vault-password-file "$VAULT_PASS" >/dev/null 2>&1; then
  echo "vault.yml exists and decrypts OK."
  echo ""
  echo "To SET or CHANGE credentials, run:"
  echo "  ./configure_vault.sh    # interactive prompts (easiest)"
  echo "  ./edit_vault.sh         # open in editor"
  exit 0
fi

echo "No working vault.yml found."
echo "Run ./configure_vault.sh to enter credentials interactively."
