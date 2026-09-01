#!/bin/bash
# Open encrypted vault.yml in your editor ($EDITOR or vi)
set -euo pipefail
cd "$(dirname "$0")"
VAULT_PASS="../linux_tanium/vault_password_file"

if [ ! -f vault.yml ]; then
  echo "vault.yml not found. Run ./configure_vault.sh first."
  exit 1
fi

export EDITOR="${EDITOR:-vi}"
echo "Opening vault.yml in $EDITOR ..."
echo "Edit the values, save, and quit the editor to re-encrypt automatically."
echo ""

ansible-vault edit vault.yml --vault-password-file "$VAULT_PASS"

echo "vault.yml updated and re-encrypted."
