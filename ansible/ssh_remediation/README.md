# vSphere SSH Remediation

Safe, inventory-gated workflow to discover Linux VMs with unreachable SSH across three vCenters and remediate `sshd_config` only on hosts you explicitly add to `inventory.txt`.

**Execution host:** `blr-kiruthika.strykercorp.com`

## vCenters

| Site | URL |
|------|-----|
| BLR | https://blr-vsphere-01.strykercorp.com/ui/app |
| STC | https://stc-vsphere-01.strykercorp.com/ui/app |
| FW  | https://fw-vsphere-01.strykercorp.com/ui/app |

## Directory layout

```
ssh_remediation/
├── ansible.cfg
├── vault.yml                 ← encrypted vCenter + guest OS creds
├── inventory.txt             ← YOU control which hosts get remediated
├── group_vars/all.yml
├── discover_ssh_status.yml   ← Phase 1: read-only discovery
├── remediate_ssh.yml         ← Phase 3: gated remediation
├── probe_inventory.yml       ← SSH probe for inventory hosts only
├── import_inventory.py       ← Optional Excel → draft inventory
├── setup_vault.sh            ← One-time vault initialization
├── filter_plugins/
└── reports/                  ← CSV/JSON output
```

## VMware PowerCLI (installed)

PowerCLI 13.3 is installed for the current user. Connect to all three vCenters using vault credentials:

```bash
cd /home/tpx-admin/ansible/ssh_remediation
./connect_vsphere.sh
```

Connection report: `reports/vsphere_connect_<timestamp>.csv`

**vSphere URLs used:**
- https://blr-vsphere-01.strykercorp.com/ui/app
- https://stc-vsphere-01.strykercorp.com/ui/app
- https://fw-vsphere-01.strykercorp.com/ui/app

**If connection fails with `System.View` or permission denied**, the vCenter account in `vault.yml` needs these privileges (ask your vCenter admin):
- `System.View` (read inventory)
- `VirtualMachine.GuestOperations.Execute` (run commands in guest for SSH fix)
- `VirtualMachine.GuestOperations.Query` (guest ops status)

Update credentials after admin grants access:
```bash
./configure_vault.sh    # or ./edit_vault.sh
./connect_vsphere.sh    # re-test
```

Manual PowerCLI session:
```powershell
cd /home/tpx-admin/ansible/ssh_remediation
$c = python3 get_vault_creds.py | ConvertFrom-Json
$sec = ConvertTo-SecureString $c.vcenter_password -AsPlainText -Force
$cred = New-Object PSCredential($c.vcenter_username, $sec)
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Connect-VIServer -Server blr-vsphere-01.strykercorp.com -Credential $cred
Get-VM | Select-Object -First 5 Name, PowerState, @{N='IP';E={$_.Guest.IPAddress}}
```

## Prerequisites

1. **Vault credentials** — `vault.yml` is **encrypted on purpose**. Do not edit it in a normal text editor.

   **Easiest way — interactive prompts:**
   ```bash
   cd /home/tpx-admin/ansible/ssh_remediation
   ./configure_vault.sh
   ```
   You will be prompted for vCenter username/password and guest OS (root) credentials.

   **Or edit in terminal editor:**
   ```bash
   ./edit_vault.sh
   # Opens vi/nano — change the values, save and quit to re-encrypt
   ```

   **Or manual ansible-vault command:**
   ```bash
   ansible-vault edit vault.yml --vault-password-file ../linux_tanium/vault_password_file
   ```

   Required keys inside vault (plain text while editing):
   ```yaml
   vcenter_username: "your_user@strykercorp.com"
   vcenter_password: "your_vcenter_password"
   guest_credentials:
     username: root
     password: "your_root_password"
   ```

   **Verify vault decrypts (does not print secrets if using view carefully):**
   ```bash
   ansible-vault view vault.yml --vault-password-file ../linux_tanium/vault_password_file
   ```

2. **Target list** — either:
   - Upload `MissingCrowdStrike.xlsx` and run `import_inventory.py`, OR
   - Manually add hosts to `inventory.txt`

3. **Network** — this VM must reach all three vCenters (443) and target VM IPs on port 22.

## Safety controls

- Remediation runs **only** on hosts in `inventory.txt` group `[ssh_unreachable]`
- `serial: 1` and `forks: 1` — one server at a time
- Pre-check skips hosts where SSH port 22 is already open
- `sshd_config` backed up before changes
- `sshd -t` validation before service restart
- Per-host JSON + CSV result reports

## Step-by-step runbook

```bash
cd /home/tpx-admin/ansible/ssh_remediation

# 0. One-time vault setup (if not done)
./configure_vault.sh

# 1. Optional: import Excel to draft inventory
python3 import_inventory.py MissingCrowdStrike.xlsx
# Review inventory.draft.txt, copy approved lines to inventory.txt

# 2. Smoke-test vCenter connectivity (read-only)
ansible-playbook discover_ssh_status.yml --tags vcenter_connect

# 3. Full discovery — generates CSV report (read-only, no VM changes)
ansible-playbook discover_ssh_status.yml

# 4. Review report
ls -lt reports/ssh_status_*.csv | head -1

# 5. Add ONLY approved unreachable hosts to inventory.txt:
#    [ssh_unreachable]
#    server01 ansible_host=10.x.x.x vcenter=blr-vsphere-01.strykercorp.com vm_name=server01

# 6. Probe inventory hosts only (no vCenter API needed)
ansible-playbook probe_inventory.yml

# 7. Dry-run remediation (skips guest ops mutations)
ansible-playbook remediate_ssh.yml --check --skip-tags guest_ops

# 8. Remediate ONE host first
ansible-playbook remediate_ssh.yml --limit server01

# 9. Remediate full approved batch (still one at a time)
ansible-playbook remediate_ssh.yml
```

## Manual vSphere console fallback

When guest operations fail (VMware Tools not running, bad guest creds):

1. Open VM console in vSphere UI
2. Login as root/admin
3. Check port 22: `ss -tlnp | grep ':22'`
4. Edit `/etc/ssh/sshd_config` — ensure uncommented:
   ```
   Port 22
   PubkeyAuthentication yes
   PasswordAuthentication yes
   ```
5. Validate: `/usr/sbin/sshd -t`
6. Restart: `systemctl restart sshd || systemctl restart ssh`
7. Verify: `ss -tlnp | grep ':22'`
8. Re-run discovery to confirm SSH restored

## Reports

| Playbook | Output |
|----------|--------|
| `discover_ssh_status.yml` | `reports/ssh_status_<timestamp>.csv` |
| `probe_inventory.yml` | `reports/probe_<timestamp>.csv` |
| `remediate_ssh.yml` | `reports/remediation_<timestamp>.json` + `.csv` |

Discovery CSV columns: vCenter, VM Name, IP, Guest OS, Power State, VMware Tools, SSH Port 22, SSH Reachable, In Inventory, Recommended Action

## Result codes

| Result | Meaning |
|--------|---------|
| SKIPPED | SSH already reachable — no changes made |
| SUCCESS | Guest ops remediated and SSH confirmed |
| PARTIAL | Guest ops ran but SSH still unreachable |
| PENDING | Manual console required |
