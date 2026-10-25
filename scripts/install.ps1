# ==============================================================================
# OmniNexus Agent 1-Line Installer for Windows (Windows Server & Windows 10/11)
# Usage:
#   powershell -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/howtosecu/OmniNexus-Agent/main/scripts/install.ps1 | iex"
# ==============================================================================

param(
    [string]$HubEndpoint = "127.0.0.1:9443",
    [string]$EnrollmentToken = "change-this-secret",
    [string]$TenantID = "org-default",
    [string]$InstallDir = "C:\Program Files\OmniNexus",
    [string]$RepoUrl = "https://github.com/howtosecu/OmniNexus-Agent"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "⚡ Starting OmniNexus Endpoint Agent Installer (Windows)" -ForegroundColor Cyan
Write-Host "   Hub Endpoint: $HubEndpoint"
Write-Host "   Tenant ID:    $TenantID"
Write-Host "   Install Dir:  $InstallDir"
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Create Target Directory
if (!(Test-Path -Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

$BinDir = Join-Path $InstallDir "bin"
if (!(Test-Path -Path $BinDir)) {
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
}

# 2. Download Latest Windows Binary from Release
$BinaryTarget = Join-Path $BinDir "nexus-agent.exe"
$DownloadUrl = "$RepoUrl/releases/latest/download/nexus-agent-windows-amd64.exe"
Write-Host "[+] Downloading latest release from $DownloadUrl..." -ForegroundColor Yellow

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinaryTarget -UseBasicParsing
    Write-Host "[+] Successfully downloaded agent binary to $BinaryTarget" -ForegroundColor Green
} catch {
    Write-Host "[-] Failed to download binary. Make sure a GitHub release exists at $RepoUrl" -ForegroundColor Red
    throw $_
}

# 3. Create Agent Configuration
$ConfigFile = Join-Path $InstallDir "agent.yaml"
$ConfigContent = @"
hub:
  endpoint: "$HubEndpoint"
  insecure: true
  reconnect_interval_sec: 5
  max_reconnect_interval_sec: 60

identity:
  tenant_id: "$TenantID"
  enrollment_token: "$EnrollmentToken"
  key_file: "$InstallDir\identity.key"
  tags:
    installer: "powershell_1line"
    os: "windows"
    arch: "amd64"

telemetry:
  enabled: true
  interval_sec: 15
  enable_ebpf: false
  enable_process_monitoring: true

execution:
  allow_shell: true
  allow_file_transfer: true
  session_timeout_sec: 3600

logging:
  level: "info"
  format: "text"
"@

Set-Content -Path $ConfigFile -Value $ConfigContent -Encoding UTF8
Write-Host "[+] Generated configuration at $ConfigFile" -ForegroundColor Green

# 4. Create Scheduled Task for Automatic Startup at Boot
$TaskName = "OmniNexusEndpointAgent"
$Action = New-ScheduledTaskAction -Execute $BinaryTarget -Argument "--config `"$ConfigFile`"" -WorkingDirectory $InstallDir
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings | Out-Null
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "✔ OmniNexus Windows Agent successfully installed & started as SYSTEM task!" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan
} catch {
    Write-Host "[!] Could not register SYSTEM scheduled task (run as Administrator to register background service)." -ForegroundColor Yellow
    Write-Host "    You can run manually: & '$BinaryTarget' --config '$ConfigFile'" -ForegroundColor Gray
}
