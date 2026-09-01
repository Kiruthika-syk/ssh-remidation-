#!/bin/bash
# Interactive vault setup — prompts for credentials and writes encrypted vault.yml
set -euo pipefail
cd "$(dirname "$0")"
VAULT_PASS="../linux_tanium/vault_password_file"

if [ ! -f "$VAULT_PASS" ]; then
  echo "ERROR: Vault password file not found: $VAULT_PASS"
  exit 1
fi

echo "=== vSphere SSH Remediation — Vault Setup ==="
echo "Enter credentials below (input hidden for passwords)."
echo ""

read -r -p "vCenter username (e.g. user@strykercorp.com): " VCENTER_USER
read -r -s -p "vCenter password: " VCENTER_PASS
echo ""
read -r -p "Guest OS username [root]: " GUEST_USER
GUEST_USER="${GUEST_USER:-root}"
read -r -s -p "Guest OS password: " GUEST_PASS
echo ""
echo ""

# Escape double quotes in passwords for YAML
escape_yaml() { printf '%s' "$1" | sed 's/"/\\"/g'; }
VCENTER_USER_E=$(escape_yaml "$VCENTER_USER")
VCENTER_PASS_E=$(escape_yaml "$VCENTER_PASS")
GUEST_USER_E=$(escape_yaml "$GUEST_USER")
GUEST_PASS_E=$(escape_yaml "$GUEST_PASS")

PLAIN=$(mktemp)
trap 'rm -f "$PLAIN"' EXIT

cat > "$PLAIN" << EOF
---
vcenter_username: "${VCENTER_USER_E}"
vcenter_password: "${VCENTER_PASS_E}"

guest_credentials:
  username: "${GUEST_USER_E}"
  password: "${GUEST_PASS_E}"
EOF

ansible-vault encrypt "$PLAIN" \
  --vault-password-file "$VAULT_PASS" \
  --encrypt-vault-id default \
  --output vault.yml

echo "Done. Credentials saved to vault.yml (encrypted)."
echo ""
echo "To change later, run either:"
echo "  ./configure_vault.sh          # re-run this prompt script"
echo "  ./edit_vault.sh               # open vault in editor"
echo ""
echo "Verify (shows keys only, passwords hidden by ansible):"
echo "  ansible-vault view vault.yml --vault-password-file $VAULT_PASS"
