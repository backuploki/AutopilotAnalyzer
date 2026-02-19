<#
.SYNOPSIS
    Autopilot Analyzer - Architect Edition
    - Deep Extraction & Auto-Collection of MDM Logs
    - MVP Community Knowledge Base Links
    - Direct Intune/Entra Admin Portal Deep-Links
    - App ID Regex Extraction & Intune Deep-Links
    - Enhanced XML Data (UPN & Profile)
    - JSON/CSV Export Capabilities
#>
[CmdletBinding()]
param (
    [string]$LogPath,
    [switch]$CollectLocal,
    [switch]$ExportJSON,
    [switch]$ExportCSV
)

# If the user runs the script with no parameters, show them how to use it
if (-not $LogPath -and -not $CollectLocal) {
    Write-Warning "No log source specified."
    Write-Host "Usage Examples:" -ForegroundColor Cyan
    Write-Host "  Collect logs from this PC: .\AutopilotAnalyzer.ps1 -CollectLocal"
    Write-Host "  Analyze an existing zip:   .\AutopilotAnalyzer.ps1 -LogPath 'C:\Path\To\Logs.zip'"
    return
}

# If they provided a LogPath, make sure the file actually exists
if ($LogPath -and -not (Test-Path $LogPath)) {
    Write-Error "LogPath not found at '$LogPath'. Please verify the file exists."
    return
}

# --- INTERNAL BRAIN: KNOWLEDGE BASE & PORTALS ---
function Get-ErrorInsight {
    param([string]$Message)
    $kb = @{
        "-2016281112" = @{ Hint = "Generic Win32 MSI Failure."; DocUrl = "https://learn.microsoft.com/en-us/mem/intune/apps/troubleshoot-app-install"; MvpUrl = "https://patchmypc.com/blog/powershell-script-installer-support-for-win32-apps-in-intune/"; MvpName = "Patch My PC"; PortalUrl = "https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/AppsWindowsMenu/~/windowsApps"; PortalName = "Intune Apps Blade" }
        "0x800705b4"  = @{ Hint = "TPM/ESP Timeout. Hardware issue."; DocUrl = "https://learn.microsoft.com/en-us/windows/deployment/windows-autopilot/troubleshoot-autopilot-errors#0x800705b4"; MvpUrl = "https://andrewstaylor.com/2022/08/16/autopilot-troubleshooting-tools-during-esp/"; MvpName = "Andrew Taylor"; PortalUrl = "https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesWindowsEnrollmentMenu/~/windowsAutopilot"; PortalName = "Autopilot Devices" }
        "AAD token"   = @{ Hint = "Azure AD comms failed. Check Network/TPM."; DocUrl = "https://learn.microsoft.com/en-us/autopilot/troubleshoot-device-enrollment"; MvpUrl = "https://patchmypc.com/blog/entra-join-no-password-prompt-user-realm-issue/"; MvpName = "Patch My PC"; PortalUrl = "https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DevicesAll"; PortalName = "Entra ID Devices" }
        "channel URI" = @{ Hint = "Push Notification failed."; DocUrl = "https://learn.microsoft.com/en-us/mem/intune/enrollment/troubleshoot-windows-enrollment-errors"; MvpUrl = "https://andrewstaylor.com/2024/09/02/enrolling-windows-devices-into-intune-a-definitive-guide/"; MvpName = "Andrew Taylor"; PortalUrl = "https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesWindowsEnrollmentMenu/~/windowsAutopilot"; PortalName = "Autopilot Devices" }
        "Timeout"     = @{ Hint = "ESP exceeded 60m limit."; DocUrl = "https://learn.microsoft.com/en-us/mem/intune/enrollment/troubleshoot-esp-timeout"; MvpUrl = "https://patchmypc.com/blog/why-do-required-apps-wait-60-minutes-after-autopilot-enrollment/"; MvpName = "Patch My PC"; PortalUrl = "https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/DeviceEnrollmentMenuBlade/~/enrollmentStatusPage"; PortalName = "Intune ESP Profiles" }
        "Defender"    = @{ Hint = "Security Baseline or Defender Onboarding failed."; DocUrl = "https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/troubleshoot-onboarding"; MvpUrl = "https://call4cloud.nl/category/microsoft-defender/"; MvpName = "Call4Cloud (Defender)"; PortalUrl = "https://security.microsoft.com/"; PortalName = "Defender Security Center" }
    }
    
    $code = if ($Message -match "(0x[0-9a-fA-F]{8}|-?\d{10})") { $Matches[0] } else { $null }
    if ($code -and $kb[$code]) { return $kb[$code] }
    if ($Message -match "AAD token|GetAADAuthToken") { return $kb["AAD token"] }
    if ($Message -match "channel URI") { return $kb["channel URI"] }
    if ($Message -match "Timeout") { return $kb["Timeout"] }
    if ($Message -match "(?i)defender|endpoint protection|wdapt") { return $kb["Defender"] }
    
    return $null
}

# --- PHASE 1: DATA COLLECTION & INGESTION ---
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$workDir = Join-Path -Path $env:TEMP -ChildPath "AutopilotAnalyzer_$timestamp"
New-Item -Path $workDir -ItemType Directory -Force | Out-Null

if ($CollectLocal) {
    Write-Host "-> [COLLECT LOCAL] Running MdmDiagnosticsTool (This takes 30-60 seconds)..." -ForegroundColor Yellow
    $LogPath = Join-Path -Path $env:TEMP -ChildPath "AutoCollectedLogs_$timestamp.cab"
    $proc = Start-Process -FilePath "MdmDiagnosticsTool.exe" -ArgumentList "-area Autopilot;DeviceProvisioning;Tpm -Cab `"$LogPath`"" -Wait -NoNewWindow -PassThru
    if ($proc.ExitCode -ne 0 -or -not (Test-Path $LogPath)) { Write-Error "Failed to collect local logs."; Exit }
}

Write-Host "-> Extracting Archives from $LogPath..." -ForegroundColor Cyan
$ext = [System.IO.Path]::GetExtension($LogPath).ToLower()
if ($ext -eq '.zip') { Expand-Archive -Path $LogPath -DestinationPath $workDir -Force }
elseif ($ext -eq '.cab') { Start-Process -FilePath "expand.exe" -ArgumentList "`"$LogPath`" -F:* `"$workDir`"" -Wait -NoNewWindow }

# Hunt for nested CABs
Get-ChildItem -Path $workDir -Filter "*.cab" -Recurse | ForEach-Object {
    $target = Join-Path $_.Directory.FullName ($_.BaseName + "_ext")
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Start-Process -FilePath "expand.exe" -ArgumentList "`"$($_.FullName)`" -F:* `"$target`"" -Wait -NoNewWindow
}

# --- PHASE 2: STATE ANALYSIS ---
Write-Host "-> Analyzing Provisioning State..." -ForegroundColor Cyan
$stateParams = @{ TenantId="Unknown"; OSVersion="Unknown"; UPN="Unknown"; Profile="Unknown" }
$xml = Get-ChildItem -Path $workDir -Filter "MDMDiagReport.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($xml) {
    [xml]$x = Get-Content $xml.FullName
    $root = if ($x.DiagReport) { $x.DiagReport } else { $x.MDMEnterpriseDiagnosticsReport }
    
    if ($root.EnterpriseConfiguration.TenantId) { $stateParams.TenantId = $root.EnterpriseConfiguration.TenantId }
    if ($root.DeviceVariables.OSVersion) { $stateParams.OSVersion = $root.DeviceVariables.OSVersion }
    if ($root.DeviceVariables.UserUPN) { $stateParams.UPN = $root.DeviceVariables.UserUPN }
    elseif ($root.EnterpriseConfiguration.UserUpn) { $stateParams.UPN = $root.EnterpriseConfiguration.UserUpn }
    if ($root.EnterpriseConfiguration.AutopilotProfileName) { $stateParams.Profile = $root.EnterpriseConfiguration.AutopilotProfileName }
}

# --- PHASE 3: LOG ANALYSIS ---
Write-Host "-> Parsing IME Logs..." -ForegroundColor Cyan
$ime = Get-ChildItem -Path $workDir -Filter "IntuneManagementExtension.log" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
$errors = @(); $apps = @()

if ($ime) {
    $rex = '<!\[LOG\[(?<Message>.*?)\]LOG\]!><time="(?<Time>.*?)" date="(?<Date>.*?)" component="(?<Component>.*?)" context=".*?" type="(?<Type>.*?)"'
    foreach ($line in [System.IO.File]::ReadLines($ime.FullName)) {
        if ($line -match $rex) {
            $m = $Matches
            if ($m.Type -eq "3" -or $m.Message -match "(?i)fail|error|timeout|exitcode") {
                $insight = Get-ErrorInsight -Message $m.Message
                $errors += [PSCustomObject]@{ 
                    Time=$m.Time; Component=$m.Component; Severity="CRITICAL"; Message=$m.Message;
                    Hint = if ($insight) { $insight.Hint } else { "" };
                    DocUrl = if ($insight) { $insight.DocUrl } else { "" };
                    MvpUrl = if ($insight) { $insight.MvpUrl } else { "" };
                    MvpName = if ($insight) { $insight.MvpName } else { "" };
                    PortalUrl = if ($insight) { $insight.PortalUrl } else { "" };
                    PortalName = if ($insight) { $insight.PortalName } else { "" }
                }
            }
            if ($m.Component -match "(?i)AppWorkload|AgentExecutor" -and $m.Message -match "(?i)Downloading|Installing|Enforcing|ExitCode") {
                $st = if ($m.Message -match "ExitCode.*0") { "Success" } elseif ($m.Message -match "ExitCode") { "Failed" } else { "Info" }
                
                # Regex to extract the App ID
                $appId = if ($m.Message -match "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})") { $Matches[1] } else { "" }
                
                $apps += [PSCustomObject]@{ Time=$m.Time; Component=$m.Component; Status=$st; AppID=$appId; Message=$m.Message }
            }
        }
    }
}

# --- PHASE 4: REPORTING & EXPORT ---
Write-Host "-> Generating Visual Dashboard..." -ForegroundColor Cyan
$css = "body{font-family:'Segoe UI',sans-serif;background:#121212;color:#e0e0e0;padding:20px}a{color:#00e5ff;text-decoration:none;border-bottom:1px dotted #00e5ff}a:hover{color:#fff}table{table-layout:fixed;width:100%;border-collapse:collapse;background:#1e1e1e;margin-bottom:20px}th{background:#2c2c2c;padding:15px;color:#00e5ff;text-align:left}td{padding:12px 15px;border-bottom:1px solid #333;word-wrap:break-word;overflow-wrap:anywhere}.status-Success{color:#00e5ff}.status-Failed{color:#ff4081}.header{border-bottom:2px solid #00e5ff;padding-bottom:20px;margin-bottom:30px}h1{color:#00e5ff;text-transform:uppercase}.hud-container{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:15px;margin-bottom:40px}.hud-card{background:#1e1e1e;padding:20px;border-left:4px solid #00e5ff}.hud-card.danger{border-left-color:#ff4081}.hud-value{font-size:1.8em;font-weight:bold;margin-bottom:5px;word-break:break-all}.hud-label{font-size:0.8em;opacity:0.7;text-transform:uppercase}.link-badge{background:#2a2a2a;padding:4px 8px;border-radius:4px;font-size:0.85em;display:inline-block;margin-top:4px;white-space:nowrap}"

$eTbl = if ($errors) { 
    $rows = $errors | ForEach-Object { 
        $docLink = if ($_.DocUrl) { "<a href='$($_.DocUrl)' target='_blank' class='link-badge'>&#128196; MS Docs</a>" } else { "" }
        $mvpLink = if ($_.MvpUrl) { "<a href='$($_.MvpUrl)' target='_blank' class='link-badge' style='color:#ff8a65;border-color:#ff8a65'>&#11088; $($_.MvpName)</a>" } else { "" }
        $portalLink = if ($_.PortalUrl) { "<a href='$($_.PortalUrl)' target='_blank' class='link-badge' style='color:#b388ff;border-color:#b388ff;font-weight:bold'>&#9881; $($_.PortalName)</a>" } else { "" }
        
        $fix = if ($_.DocUrl -or $_.PortalUrl) { 
            "<div style='margin-bottom:6px'><strong>$($_.Hint)</strong></div>
             <div style='display:flex; gap:5px; flex-wrap:wrap'>$docLink $mvpLink $portalLink</div>"
        } else { $_.Hint }
        
        "<tr><td style='width:15%'>$($_.Time)</td><td style='color:#ff4081;width:10%'>$($_.Severity)</td><td style='width:15%'>$($_.Component)</td><td style='width:35%'>$($_.Message)</td><td style='width:25%'>$fix</td></tr>" 
    }
    "<table><tr><th>Time</th><th>Severity</th><th>Component</th><th>Message</th><th>Remediation & Portals</th></tr>$rows</table>" 
} else { "<p>No Critical Errors Found.</p>" }

$aTbl = if ($apps) {
    $rows = $apps | ForEach-Object { 
        $idDisplay = if ($_.AppID) { "<a href='https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/AppWorkloadReadOnlyDocument/~/appId/$($_.AppID)' target='_blank' class='link-badge' style='color:#00e5ff;border-color:#00e5ff'>&#128230; $($_.AppID.Substring(0,8))...</a>" } else { "N/A" }
        "<tr><td style='width:15%'>$($_.Time)</td><td style='width:15%'>$($_.Component)</td><td style='width:10%' class='status-$($_.Status)'>$($_.Status)</td><td style='width:15%'>$idDisplay</td><td style='width:45%'>$($_.Message)</td></tr>" 
    }
    $rows
} else {
    "<tr><td colspan='5' style='text-align:center'>No App Telemetry Found.</td></tr>"
}
$aTblFinal = "<table><tr><th>Time</th><th>Component</th><th>Status</th><th>App ID</th><th>Message</th></tr>$aTbl</table>"

$path = Join-Path $env:TEMP "Autopilot_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
"<!DOCTYPE html><html><head><title>Autopilot Diagnostic System</title><style>$css</style></head><body><div class='header'><h1>Autopilot Diagnostic System</h1></div><div class='hud-container'><div class='hud-card $(if($errors){'danger'})'><div class='hud-value'>$($errors.Count)</div><div class='hud-label'>Critical Failures</div></div><div class='hud-card'><div class='hud-value'>$($apps.Count)</div><div class='hud-label'>Events Tracked</div></div><div class='hud-card'><div class='hud-value'>$($stateParams.UPN)</div><div class='hud-label'>User UPN</div></div><div class='hud-card'><div class='hud-value'>$($stateParams.Profile)</div><div class='hud-label'>Autopilot Profile</div></div></div><h2>Critical Failures</h2>$eTbl<h2>App Telemetry</h2>$aTblFinal</body></html>" | Out-File $path -Encoding utf8

# --- EXPORT LOGIC ---
if ($ExportJSON) {
    $jsonPath = Join-Path $env:TEMP "AutopilotData_$timestamp.json"
    @{ State = $stateParams; Errors = $errors; Apps = $apps } | ConvertTo-Json -Depth 4 | Out-File $jsonPath -Encoding utf8
    Write-Host "[OK] JSON Exported: $jsonPath" -ForegroundColor Green
}
if ($ExportCSV -and $errors) {
    $csvPath = Join-Path $env:TEMP "AutopilotErrors_$timestamp.csv"
    $errors | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "[OK] CSV Exported: $csvPath" -ForegroundColor Green
}

Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
Invoke-Item $path
Write-Host "[ COMPLETE ]" -ForegroundColor DarkGreen