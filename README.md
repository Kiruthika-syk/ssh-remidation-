# SSH Remediation & Falcon Installation

Ansible automation for vSphere Linux SSH remediation and CrowdStrike Falcon sensor deployment.

## Repository layout

```
ansible/
├── ssh_remediation/          # vSphere SSH discovery & remediation
│   ├── discover_ssh_status.yml
│   ├── remediate_ssh.yml
│   ├── probe_inventory.yml
│   ├── run_pipeline.sh
│   └── README.md             # Detailed runbook
├── falcon_token.yml          # CrowdStrike Falcon install playbook
└── falcon_token.ini.example  # Copy to falcon_token.ini (not in git)
```

## Quick start

### SSH remediation

```bash
cd ansible/ssh_remediation
./setup_vault.sh              # Create encrypted vault.yml
./configure_vault.sh            # Set vCenter + guest OS credentials
python3 import_inventory.py MissingCrowdStrike40.xlsx -o inventory.txt
./run_pipeline.sh
```

See [ansible/ssh_remediation/README.md](ansible/ssh_remediation/README.md) for the full runbook.

### Falcon installation

```bash
cd ansible
cp falcon_token.ini.example falcon_token.ini
# Edit falcon_token.ini — set SSH creds and target IPs
ansible-playbook falcon_token.yml -i falcon_token.ini -f 1
```

## Secrets

Do **not** commit credentials. These files are gitignored:

- `ansible/falcon_token.ini` — SSH passwords and host list
- `ansible/ssh_remediation/vault.yml` — vCenter and guest OS credentials

Use `vault.yml.example` and `falcon_token.ini.example` as templates.

## vCenters

| Site | URL |
|------|-----|
| BLR | https://blr-vsphere-01.strykercorp.com/ui/app |
| STC | https://stc-vsphere-01.strykercorp.com/ui/app |
| FW  | https://fw-vsphere-01.strykercorp.com/ui/app |
