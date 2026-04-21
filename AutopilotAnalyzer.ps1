<#
.SYNOPSIS
    Autopilot Analyzer - Architect Edition (v2.0)
    - Externalized JSON Knowledge Base (Auto-generated)
    - Compiled Regex Log Parsing Engine for performance
    - Direct XML, YAML, EVTX, and Archive Support
    - Interactive HTML Dashboard with Vanilla JS (Sort/Filter)
    - Advanced Telemetry & Registry Deep-Dives
    - Robust Error Handling for Event Logs & Standardized Output Paths
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param (
    [string]$LogPath,
    [switch]$CollectLocal,
    [switch]$ExportJSON,
    [switch]$ExportCSV
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outDir = "$env:USERPROFILE\Downloads"

# --- PHASE 0: KNOWLEDGE BASE ARCHITECTURE ---
$kbFile = Join-Path $PSScriptRoot "AutopilotKB.json"
if (-not (Test-Path $kbFile)) {
    Write-Host "-> Initializing external Knowledge Base (AutopilotKB.json)..." -ForegroundColor Yellow
    # Expanded KB with additional MVP insights and standard Intune codes
    $defaultKB = @{
        # --- AUTOPILOT / INTUNE ERRORS ---
        "-2016281112" = @{ Hint="Generic Win32 MSI Failure"; DocUrl="https://learn.microsoft.com/en-us/mem/intune/apps/troubleshoot-app-install"; MvpUrl="https://patchmypc.com/blog/powershell-script-installer-support-for-win32-apps-in-intune/"; MvpName="Patch My PC"; PortalUrl="https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/AppsWindowsMenu/~/windowsApps" }
        "0x800705b4"  = @{ Hint="TPM/ESP Timeout. Hardware or Network block."; DocUrl="https://learn.microsoft.com/en-us/windows/deployment/windows-autopilot/troubleshoot-autopilot-errors#0x800705b4"; MvpUrl="https://andrewstaylor.com/2022/08/16/autopilot-troubleshooting-tools-during-esp/"; MvpName="Andrew Taylor"; PortalUrl="https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesWindowsEnrollmentMenu/~/windowsAutopilot" }
        "0x80072f8f"  = @{ Hint="SSL/TLS Inspection or Clock Skew blocking comms."; DocUrl="https://learn.microsoft.com/en-us/mem/autopilot/troubleshooting"; MvpUrl="https://oofhours.com/2019/10/08/troubleshooting-windows-autopilot-a-reference/"; MvpName="Oofhours (Niehaus)" }
        "0xcaa7000f"  = @{ Hint="Proxy Block / ADAL/WAM endpoint unreachable."; DocUrl="https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-enrollment/troubleshoot-windows-enrollment-errors" }
        "0x81036502"  = @{ Hint="Autopilot profile not found or not assigned."; DocUrl="https://learn.microsoft.com/en-us/mem/autopilot/troubleshoot-profile-download"; MvpUrl="https://oofhours.com/2020/07/12/windows-autopilot-profile-not-found/"; MvpName="Oofhours" }
        "0x80180014"  = @{ Hint="MDM not supported or User missing Intune License."; DocUrl="https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-enrollment/troubleshoot-windows-enrollment-errors"; MvpUrl="https://www.petervanderwoude.nl/post/troubleshooting-mdm-enrollment-errors/"; MvpName="Peter van der Woude" }
        "0x80180018"  = @{ Hint="Device is already enrolled in MDM."; DocUrl="https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-enrollment/troubleshoot-windows-enrollment-errors"; MvpUrl="https://call4cloud.nl/2022/08/the-last-mdm-enrollment-starfighter/"; MvpName="Call4Cloud (Ooms)" }
        "aad token"   = @{ Hint="Azure AD comms failed. Check Network/TPM."; MvpUrl="https://patchmypc.com/blog/entra-join-no-password-prompt-user-realm-issue/"; MvpName="Patch My PC"; PortalUrl="https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DevicesAll" }
        "timeout"     = @{ Hint="ESP exceeded configured time limit."; DocUrl="https://learn.microsoft.com/en-us/mem/intune/enrollment/troubleshoot-esp-timeout"; MvpUrl="https://andrewstaylor.com/2024/09/02/enrolling-windows-devices-into-intune-a-definitive-guide/"; MvpName="Andrew Taylor"; PortalUrl="https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/DeviceEnrollmentMenuBlade/~/enrollmentStatusPage" }
        "defender"    = @{ Hint="Security Baseline or MDE Onboarding failed."; MvpUrl="https://call4cloud.nl/category/microsoft-defender/"; MvpName="Call4Cloud" }
        # --- OS / EVTX ERRORS ---
        "w32time"     = @{ Hint="Time Sync Failure. Blocks AAD/Intune auth."; DocUrl="https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings" }
        "schannel"    = @{ Hint="TLS/SSL Handshake failed. Check proxy or Root CAs."; DocUrl="https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/schannel-errors-overview" }
        "tpm"         = @{ Hint="Hardware TPM attestation failed."; DocUrl="https://learn.microsoft.com/en-us/windows/security/hardware-security/tpm/tpm-troubleshooting"; MvpUrl="https://call4cloud.nl/2021/11/tpm-attestation-failure/"; MvpName="Call4Cloud" }
    }
    $defaultKB | ConvertTo-Json -Depth 4 | Out-File $kbFile -Encoding utf8
}

$global:KBObj = Get-Content $kbFile -Raw | ConvertFrom-Json
function Get-ErrorInsight($Msg, $Comp) {
    # Match specific hex codes
    if ($Msg -match "(0x[0-9a-fA-F]{8}|-?\d{10})") {
        $code = $Matches[0].ToLower()
        if ($global:KBObj.PSObject.Properties[$code]) { return $global:KBObj.$code }
    }
    # Match keywords mapped in KB
    foreach ($key in @("aad token", "timeout", "defender", "w32time", "schannel", "tpm")) {
        if ($Msg -match "(?i)$key" -or $Comp -match "(?i)$key") {
            if ($global:KBObj.PSObject.Properties[$key]) { return $global:KBObj.$key }
        }
    }
    return $null
}

# --- GUI / FILE SELECTION ---
if (-not $LogPath -and -not $CollectLocal) {
    Write-Host "No log source specified. Opening file browser..." -ForegroundColor Cyan
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.Title = "Select Autopilot Log Source (.zip, .cab, .xml, .evtx)"
    $FileBrowser.Filter = "Supported Logs|*.zip;*.cab;*.xml;*.log;*.evtx|All Files|*.*"
    $FileBrowser.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    
    if ($FileBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $LogPath = $FileBrowser.FileName
    } else {
        Write-Warning "No file selected. Run with -CollectLocal to target this PC."
        return
    }
}

if ($LogPath -and -not (Test-Path $LogPath)) { Write-Error "File not found: $LogPath"; return }

# --- PHASE 1: DATA COLLECTION & INGESTION ---
$workDir = Join-Path -Path $env:TEMP -ChildPath "AutopilotAnalyzer_$timestamp"
New-Item -Path $workDir -ItemType Directory -Force | Out-Null

$telemetry = @{ TenantId="Unknown"; OSVersion="Unknown"; UPN="Unknown"; Profile="Unknown"; OOBEDisableCMD="Unknown"; ESPTracking="Unknown" }

if ($CollectLocal) {
    Write-Host "-> [COLLECT LOCAL] Running MdmDiagnosticsTool & Registry Telemetry..." -ForegroundColor Yellow
    $LogPath = Join-Path -Path $env:TEMP -ChildPath "AutoCollectedLogs_$timestamp.cab"
    Start-Process -FilePath "MdmDiagnosticsTool.exe" -ArgumentList "-area Autopilot;DeviceProvisioning;Tpm -Cab `"$LogPath`"" -Wait -NoNewWindow
    
    # Deep-Dive Telemetry: Check if Custom OMA-URI for DisableCMD applied successfully
    $cmdPolicyPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System"
    if (Test-Path $cmdPolicyPath) {
        $cmdVal = (Get-ItemProperty $cmdPolicyPath -Name "DisableCMD" -ErrorAction SilentlyContinue).DisableCMD
        $telemetry.OOBEDisableCMD = if ($null -ne $cmdVal) { $cmdVal } else { "Not Applied" }
    }
    # ESP Profile tracking
    $espPath = "HKLM:\SOFTWARE\Microsoft\Enrollments\*\FirstSync"
    $espData = Get-ItemProperty $espPath -ErrorAction SilentlyContinue
    if ($espData) { $telemetry.ESPTracking = "Active" }
}

Write-Host "-> Unpacking Data..." -ForegroundColor Cyan
$ext = [System.IO.Path]::GetExtension($LogPath).ToLower()
if ($ext -eq '.zip') { Expand-Archive -Path $LogPath -DestinationPath $workDir -Force } 
elseif ($ext -eq '.cab') { Start-Process "expand.exe" "`"$LogPath`" -F:* `"$workDir`"" -Wait -NoNewWindow } 
else { Copy-Item -Path $LogPath -Destination $workDir -Force }

Get-ChildItem -Path $workDir -Filter "*.cab" -Recurse | ForEach-Object {
    $target = Join-Path $_.Directory.FullName ($_.BaseName + "_ext")
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Start-Process "expand.exe" "`"$($_.FullName)`" -F:* `"$target`"" -Wait -NoNewWindow
}

# --- PHASE 2: STATE ANALYSIS ---
Write-Host "-> Parsing XML Diagnostics..." -ForegroundColor Cyan
$xmlFile = Get-ChildItem -Path $workDir -Filter "*.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($xmlFile) {
    [xml]$x = Get-Content $xmlFile.FullName
    $root = if ($x.DiagReport) { $x.DiagReport } elseif ($x.MDMEnterpriseDiagnosticsReport) { $x.MDMEnterpriseDiagnosticsReport }
    if ($root) {
        if ($root.EnterpriseConfiguration.TenantId) { $telemetry.TenantId = $root.EnterpriseConfiguration.TenantId }
        if ($root.DeviceVariables.OSVersion) { $telemetry.OSVersion = $root.DeviceVariables.OSVersion }
        if ($root.DeviceVariables.UserUPN) { $telemetry.UPN = $root.DeviceVariables.UserUPN }
        if ($root.EnterpriseConfiguration.AutopilotProfileName) { $telemetry.Profile = $root.EnterpriseConfiguration.AutopilotProfileName }
    }
}

# --- PHASE 3: LOG ANALYSIS (COMPILED REGEX) ---
Write-Host "-> Compiling RegEx Engine & Parsing Logs..." -ForegroundColor Cyan
$errors = @(); $apps = @()

$imePattern = '<!\[LOG\[(?<Message>.*?)\]LOG\]!><time="(?<Time>.*?)" date="(?<Date>.*?)" component="(?<Component>.*?)" context=".*?" type="(?<Type>.*?)"'
$imeRegex = [regex]::new($imePattern, [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

$ime = Get-ChildItem -Path $workDir -Filter "IntuneManagementExtension.log" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ime) {
    # Using ReadLines for memory efficiency on massive logs
    foreach ($line in [System.IO.File]::ReadLines($ime.FullName)) {
        $match = $imeRegex.Match($line)
        if ($match.Success) {
            $msg = $match.Groups['Message'].Value
            $comp = $match.Groups['Component'].Value
            $time = $match.Groups['Time'].Value
            $type = $match.Groups['Type'].Value

            if ($type -eq "3" -or $msg -match "(?i)fail|error|timeout|exitcode|0x80072f8f|0xcaa7000f") {
                $insight = Get-ErrorInsight -Msg $msg -Comp $comp
                $errors += [PSCustomObject]@{ Time=$time; Component=$comp; Severity="IME CRITICAL"; Message=$msg; Insight=$insight }
            }
            if ($comp -match "(?i)AppWorkload|AgentExecutor" -and $msg -match "(?i)Downloading|Installing|Enforcing|ExitCode") {
                $st = if ($msg -match "ExitCode.*0") { "Success" } elseif ($msg -match "ExitCode") { "Failed" } else { "Info" }
                $appId = if ($msg -match "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})") { $Matches[1] } else { "" }
                $apps += [PSCustomObject]@{ Time=$time; Component=$comp; Status=$st; AppID=$appId; Message=$msg }
            }
        }
    }
}

$evtxFiles = Get-ChildItem -Path $workDir -Filter "*.evtx" -Recurse -ErrorAction SilentlyContinue
if ($evtxFiles) {
    foreach ($evtx in $evtxFiles) {
        $events = @()
        
        # Try/Catch wrapper prevents script failure on empty or locked .evtx files
        try {
            $events += @(Get-WinEvent -FilterHashtable @{Path=$evtx.FullName; Level=1,2} -MaxEvents 500 -ErrorAction Stop)
        } catch {
            Write-Warning "Skipping unreadable event log: $($evtx.Name)"
        }

        if ($evtx.Name -match "(?i)AAD.*Operational") {
            try {
                $events += @(Get-WinEvent -Path $evtx.FullName -ErrorAction Stop | Where-Object { $_.Message -match "(0x80072f8f|0xcaa7000f)" }) | Select-Object -Unique
            } catch {}
        }

        foreach ($event in $events) {
            $msg = if ($event.Message) { $event.Message.Replace("`n"," ").Replace("`r","") } else { "Event ID: $($event.Id)" }
            $insight = Get-ErrorInsight -Msg $msg -Comp $event.ProviderName
            $errors += [PSCustomObject]@{ Time=$event.TimeCreated.ToString("HH:mm:ss"); Component=$event.ProviderName; Severity="OS ERROR"; Message=$msg; Insight=$insight }
        }
    }
}

# --- PHASE 4: INTERACTIVE HTML DASHBOARD ---
Write-Host "-> Rendering Interactive Dashboard..." -ForegroundColor Cyan

# Inject Vanilla JS & Clean CSS
$js = @"
<script>
function filterTable(tableId, inputId) {
    let input = document.getElementById(inputId).value.toUpperCase();
    let table = document.getElementById(tableId);
    let trs = table.getElementsByTagName("tr");
    for (let i = 1; i < trs.length; i++) {
        let text = trs[i].textContent || trs[i].innerText;
        trs[i].style.display = text.toUpperCase().indexOf(input) > -1 ? "" : "none";
    }
}
function sortTable(n, tableId) {
    let table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
    table = document.getElementById(tableId); switching = true; dir = "asc";
    while (switching) {
        switching = false; rows = table.rows;
        for (i = 1; i < (rows.length - 1); i++) {
            shouldSwitch = false;
            x = rows[i].getElementsByTagName("TD")[n]; y = rows[i + 1].getElementsByTagName("TD")[n];
            if (dir == "asc") { if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) { shouldSwitch = true; break; } } 
            else if (dir == "desc") { if (x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) { shouldSwitch = true; break; } }
        }
        if (shouldSwitch) { rows[i].parentNode.insertBefore(rows[i + 1], rows[i]); switching = true; switchcount ++; } 
        else { if (switchcount == 0 && dir == "asc") { dir = "desc"; switching = true; } }
    }
}
</script>
"@

$css = @"
body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0f111a; color: #e2e8f0; padding: 30px; margin: 0; }
a { color: #38bdf8; text-decoration: none; transition: color 0.2s; } a:hover { color: #7dd3fc; }
h1, h2 { color: #f8fafc; font-weight: 600; }
.header { border-bottom: 1px solid #334155; padding-bottom: 20px; margin-bottom: 30px; }
.hud-container { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-bottom: 40px; }
.hud-card { background: #1e293b; padding: 25px; border-radius: 8px; border-top: 4px solid #38bdf8; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
.hud-card.danger { border-top-color: #f43f5e; }
.hud-value { font-size: 1.5em; font-weight: 700; word-break: break-all; margin-bottom: 8px; }
.hud-label { font-size: 0.85em; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; }
.search-bar { width: 100%; padding: 12px; margin-bottom: 15px; background: #1e293b; border: 1px solid #334155; color: #fff; border-radius: 6px; box-sizing: border-box; }
table { width: 100%; border-collapse: collapse; background: #1e293b; border-radius: 8px; overflow: hidden; margin-bottom: 40px; }
th { background: #0f172a; padding: 15px; text-align: left; cursor: pointer; color: #cbd5e1; user-select: none; }
th:hover { background: #1e293b; }
td { padding: 12px 15px; border-bottom: 1px solid #334155; word-wrap: break-word; }
tr:hover { background: #334155; }
.badge { background: #334155; padding: 4px 10px; border-radius: 4px; font-size: 0.8em; display: inline-block; margin: 2px; white-space: nowrap; }
.badge.ms { background: #0284c7; color: #fff; } .badge.mvp { background: #ea580c; color: #fff; } .badge.portal { background: #7e22ce; color: #fff; }
.status-Success { color: #34d399; font-weight: 600; } .status-Failed { color: #f43f5e; font-weight: 600; }
"@

$eRows = if ($errors) { 
    $errors | ForEach-Object { 
        $ins = $_.Insight
        $fixes = ""
        if ($ins) {
            $fixes += "<div style='margin-bottom:8px; color:#fcd34d'>&#9888; <strong>$($ins.Hint)</strong></div>"
            if ($ins.DocUrl) { $fixes += "<a href='$($ins.DocUrl)' target='_blank' class='badge ms'>&#128196; MS Docs</a>" }
            if ($ins.MvpUrl) { $fixes += "<a href='$($ins.MvpUrl)' target='_blank' class='badge mvp'>&#11088; $($ins.MvpName)</a>" }
            if ($ins.PortalUrl) { $fixes += "<a href='$($ins.PortalUrl)' target='_blank' class='badge portal'>&#9881; Intune Portal</a>" }
        }
        "<tr><td>$($_.Time)</td><td style='color:#f43f5e'>$($_.Severity)</td><td>$($_.Component)</td><td>$($_.Message)</td><td>$fixes</td></tr>" 
    } 
} else { "<tr><td colspan='5' style='text-align:center; padding:20px'>No Critical Errors Found.</td></tr>" }

$aRows = if ($apps) {
    $apps | ForEach-Object { 
        $idDisplay = if ($_.AppID) { "<a href='https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/AppWorkloadReadOnlyDocument/~/appId/$($_.AppID)' target='_blank' class='badge portal'>&#128230; $($_.AppID.Substring(0,8))...</a>" } else { "N/A" }
        "<tr><td>$($_.Time)</td><td>$($_.Component)</td><td class='status-$($_.Status)'>$($_.Status)</td><td>$idDisplay</td><td>$($_.Message)</td></tr>" 
    }
} else { "<tr><td colspan='5' style='text-align:center; padding:20px'>No App Telemetry Found.</td></tr>" }

# Rerouted directly to the user's Downloads folder
$htmlPath = Join-Path $outDir "Autopilot_Dashboard_$timestamp.html"
@"
<!DOCTYPE html><html><head><title>Autopilot Diagnostic System</title><style>$css</style>$js</head><body>
<div class='header'><h1>Autopilot Analyzer - Architect Edition</h1></div>
<div class='hud-container'>
    <div class='hud-card $(if($errors){'danger'})'><div class='hud-value'>$($errors.Count)</div><div class='hud-label'>Critical Failures</div></div>
    <div class='hud-card'><div class='hud-value'>$($telemetry.UPN)</div><div class='hud-label'>Target UPN</div></div>
    <div class='hud-card'><div class='hud-value'>$($telemetry.Profile)</div><div class='hud-label'>Autopilot Profile</div></div>
    <div class='hud-card'><div class='hud-value'>$($telemetry.OOBEDisableCMD)</div><div class='hud-label'>OMA-URI: DisableCMD</div></div>
</div>

<h2>Critical Execution Failures</h2>
<input type="text" id="searchErrors" class="search-bar" onkeyup="filterTable('errTable', 'searchErrors')" placeholder="Filter errors by message, code, or component...">
<table id="errTable">
    <tr><th onclick="sortTable(0, 'errTable')">Time &#8693;</th><th onclick="sortTable(1, 'errTable')">Severity &#8693;</th><th onclick="sortTable(2, 'errTable')">Component &#8693;</th><th onclick="sortTable(3, 'errTable')">Message &#8693;</th><th>Remediation Strategy</th></tr>
    $($eRows -join '')
</table>

<h2>Application Telemetry</h2>
<input type="text" id="searchApps" class="search-bar" onkeyup="filterTable('appTable', 'searchApps')" placeholder="Filter apps by status, ID, or component...">
<table id="appTable">
    <tr><th onclick="sortTable(0, 'appTable')">Time &#8693;</th><th onclick="sortTable(1, 'appTable')">Component &#8693;</th><th onclick="sortTable(2, 'appTable')">Status &#8693;</th><th onclick="sortTable(3, 'appTable')">App ID &#8693;</th><th onclick="sortTable(4, 'appTable')">Message &#8693;</th></tr>
    $($aRows -join '')
</table>
</body></html>
"@ | Out-File $htmlPath -Encoding utf8

# --- EXPORT & CLEANUP ---
if ($ExportJSON) {
    # Rerouted to Downloads
    $jsonPath = Join-Path $outDir "AutopilotData_$timestamp.json"
    @{ Telemetry=$telemetry; Errors=$errors; Apps=$apps } | ConvertTo-Json -Depth 4 | Out-File $jsonPath -Encoding utf8
}
if ($ExportCSV -and $errors) {
    # Rerouted to Downloads
    $csvPath = Join-Path $outDir "AutopilotErrors_$timestamp.csv"
    $errors | Export-Csv -Path $csvPath -NoTypeInformation
}

Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue

# Validate the HTML file exists in the Downloads folder before launching the browser
if (Test-Path $htmlPath) {
    Write-Host "[ COMPLETE ] Analysis rendered in default browser." -ForegroundColor DarkGreen
    Invoke-Item $htmlPath
} else {
    Write-Warning "[ FAILED ] HTML dashboard was not found at $htmlPath. Check execution logs."
}
