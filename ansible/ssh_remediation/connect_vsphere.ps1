# Connect to vSphere vCenters using credentials from encrypted vault.yml
# Usage: ./connect_vsphere.ps1 [-TestOnly]

param(
    [switch]$TestOnly
)

$ErrorActionPreference = "Stop"
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$credsJson = & python3 "$scriptDir/get_vault_creds.py"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to read vault credentials"
    exit 1
}
$creds = $credsJson | ConvertFrom-Json
if ($creds.error) {
    Write-Error $creds.error
    exit 1
}

$vcenters = @(
    "blr-vsphere-01.strykercorp.com"
    "stc-vsphere-01.strykercorp.com"
    "fw-vsphere-01.strykercorp.com"
)

$securePass = ConvertTo-SecureString $creds.vcenter_password -AsPlainText -Force
$viCred = New-Object System.Management.Automation.PSCredential($creds.vcenter_username, $securePass)

$results = @()
foreach ($server in $vcenters) {
    Write-Host "`n=== Connecting to $server ===" -ForegroundColor Cyan
    try {
        $conn = Connect-VIServer -Server $server -Credential $viCred -ErrorAction Stop
        $vmCount = (Get-VM -Server $conn | Measure-Object).Count
        Write-Host "  CONNECTED — User: $($conn.User) — VMs visible: $vmCount" -ForegroundColor Green
        $results += [PSCustomObject]@{
            vCenter = $server
            Status  = "Connected"
            User    = $conn.User
            VMCount = $vmCount
            Error   = ""
        }
        if (-not $TestOnly) {
            # Keep session open — list powered-on Linux VMs with target IPs if inventory exists
        }
    }
    catch {
        Write-Host "  FAILED — $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            vCenter = $server
            Status  = "Failed"
            User    = ""
            VMCount = 0
            Error   = $_.Exception.Message
        }
    }
}

Write-Host "`n=== Connection Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$reportDir = Join-Path $scriptDir "reports"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir | Out-Null }
$reportFile = Join-Path $reportDir ("vsphere_connect_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date))
$results | Export-Csv -Path $reportFile -NoTypeInformation
Write-Host "Report saved: $reportFile"

$failed = ($results | Where-Object { $_.Status -eq "Failed" }).Count
if ($failed -gt 0) { exit 1 }
exit 0
