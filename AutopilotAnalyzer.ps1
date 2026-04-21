<#
.SYNOPSIS
    Autopilot Analyzer - Architect Edition (v2.6)
    - Externalized JSON Knowledge Base
    - Compiled Regex Log Parsing Engine
    - Direct XML, YAML, EVTX, and Archive Support
    - Interactive HTML Dashboard with Vanilla JS (Sort/Filter)
    - Collapsible Event Grouping & App Timelines
    - HTML Log Sanitization (Prevents DOM Corruption)
    - Namespace-Agnostic XML Extraction
    - Dynamic MDM App ID Extraction
    - WHfB & PRT Authentication Tracking
    - Resolved ForEach-Object Pipeline Parser Bug
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

# --- HELPER FUNCTIONS ---
function Get-SafeHtml($text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    return $text.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")
}

# --- PHASE 0: KNOWLEDGE BASE ARCHITECTURE ---
$kbFile = Join-Path $PSScriptRoot "AutopilotKB.json"
if (-not (Test-Path $kbFile)) {
    Write-Host "-> Initializing external Knowledge Base (AutopilotKB.json)..." -ForegroundColor Yellow
    $defaultKB = @{
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
        "w32time"     = @{ Hint="Time Sync Failure. Blocks AAD/Intune auth."; DocUrl="https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings" }
        "schannel"    = @{ Hint="TLS/SSL Handshake failed. Check proxy or Root CAs."; DocUrl="https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/schannel-errors-overview" }
        "tpm"         = @{ Hint="Hardware TPM attestation failed."; DocUrl="https://learn.microsoft.com/en-us/windows/security/hardware-security/tpm/tpm-troubleshooting"; MvpUrl="https://call4cloud.nl/2021/11/tpm-attestation-failure/"; MvpName="Call4Cloud" }
    }
    $defaultKB | ConvertTo-Json -Depth 4 | Out-File $kbFile -Encoding utf8
}

$global:KBObj = Get-Content $kbFile -Raw | ConvertFrom-Json
function Get-ErrorInsight($Msg, $Comp) {
    if ($Msg -match "(0x[0-9a-fA-F]{8}|-?\d{10})") {
        $code = $Matches[0].ToLower()
        if ($global:KBObj.PSObject.Properties[$code]) { return $global:KBObj.$code }
    }
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
    
    $cmdPolicyPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System"
    if (Test-Path $cmdPolicyPath) {
        $cmdVal = (Get-ItemProperty $cmdPolicyPath -Name "DisableCMD" -ErrorAction SilentlyContinue).DisableCMD
        $telemetry.OOBEDisableCMD = if ($null -ne $cmdVal) { $cmdVal } else { "Not Applied" }
    }
    
    $espPath = "HKLM:\SOFTWARE\Microsoft\Enrollments\*\FirstSync"
    $espData = Get-ItemProperty $espPath -ErrorAction SilentlyContinue
    if ($espData) { $telemetry.ESPTracking = "Active" }

    $apRegPath = "HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot"
    if (Test-Path $apRegPath) {
        $apName = (Get-ItemProperty $apRegPath -Name "ProfileName" -ErrorAction SilentlyContinue).ProfileName
        if ($apName) { $telemetry.Profile = $apName }
    }

    # Deep Local JSON Fallback
    if ($telemetry.Profile -eq "Unknown") {
        $localZTD = "C:\Windows\Provisioning\Autopilot\AutopilotDDSZTDFile.json"
        if (Test-Path $localZTD) {
            try { $telemetry.Profile = (Get-Content $localZTD -Raw | ConvertFrom-Json).ZtdProfileName } catch {}
        }
    }
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

# --- PHASE 2: STATE ANALYSIS (REGEX XML BYPASS) ---
Write-Host "-> Parsing Diagnostics & Payloads..." -ForegroundColor Cyan

$xmlFile = Get-ChildItem -Path $workDir -Filter "*.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($xmlFile) {
    $xmlText = Get-Content $xmlFile.FullName -Raw
    
    if ($xmlText -match "<TenantId>(.*?)</TenantId>") { $telemetry.TenantId = $Matches[1] }
    if ($xmlText -match "<OSVersion>(.*?)</OSVersion>") { $telemetry.OSVersion = $Matches[1] }
    if ($xmlText -match "<UserUPN>(.*?)</UserUPN>") { $telemetry.UPN = $Matches[1] }
    
    if ($telemetry.Profile -eq "Unknown" -and $xmlText -match "<AutopilotProfileName>(.*?)</AutopilotProfileName>") { 
        if (-not [string]::IsNullOrWhiteSpace($Matches[1])) { $telemetry.Profile = $Matches[1] }
    }
}

if ($telemetry.Profile -eq "Unknown") {
    $jsonFile = Get-ChildItem -Path $workDir -Filter "AutopilotDDSZTDFile.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($jsonFile) {
        try {
            $apJson = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            if ($apJson.ZtdProfileName) { $telemetry.Profile = $apJson.ZtdProfileName }
        } catch {}
    }
}

# --- PHASE 3: LOG ANALYSIS (COMPILED REGEX) ---
Write-Host "-> Compiling RegEx Engine & Parsing Logs..." -ForegroundColor Cyan
$errors = @(); $apps = @()

$imePattern = '<!\[LOG\[(?<Message>.*?)\]LOG\]!><time="(?<Time>.*?)" date="(?<Date>.*?)" component="(?<Component>.*?)" context=".*?" type="(?<Type>.*?)"'
$imeRegex = [regex]::new($imePattern, [System.Text.RegularExpressions.RegexOptions]::Compiled -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

$ime = Get-ChildItem -Path $workDir -Filter "IntuneManagementExtension.log" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ime) {
    foreach ($line in [System.IO.File]::ReadLines($ime.FullName)) {
        $match = $imeRegex.Match($line)
        if ($match.Success) {
            $msg = $match.Groups['Message'].Value
            $comp = $match.Groups['Component'].Value
            $time = $match.Groups['Time'].Value
            $type = $match.Groups['Type'].Value

            $safeMsg = Get-SafeHtml $msg

            if ($type -eq "3" -or $msg -match "(?i)fail|error|timeout|exit\s?code|0x80072f8f|0xcaa7000f") {
                $insight = Get-ErrorInsight -Msg $msg -Comp $comp
                $errors += [PSCustomObject]@{ Time=$time; Component=$comp; Severity="IME CRITICAL"; Message=$safeMsg; Insight=$insight }
            }
            
            $isAppLog = ($comp -match "(?i)AppWorkload|AgentExecutor|Win32App") -or ($msg -match "(?i)\[Win32App\]|\[AppWorkload\]")
            $isAction = ($msg -match "(?i)Downloading|Installing|Enforcing|Exit\s?Code")
            
            if ($isAppLog -and $isAction) {
                $st = if ($msg -match "(?i)Exit\s?Code.*0|completed successfully") { "Success" } elseif ($msg -match "(?i)Exit\s?Code|failed") { "Failed" } else { "Info" }
                
                $idMatch = [regex]::Match($msg, "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})")
                $appId = if ($idMatch.Success) { $idMatch.Groups[1].Value } else { "" }
                
                $apps += [PSCustomObject]@{ Time=$time; Component=$comp; Status=$st; AppID=$appId; Message=$safeMsg }
            }
        }
    }
}

$evtxFiles = Get-ChildItem -Path $workDir -Filter "*.evtx" -Recurse -ErrorAction SilentlyContinue
if ($evtxFiles) {
    foreach ($evtx in $evtxFiles) {
        $events = @()
        try { $events += @(Get-WinEvent -FilterHashtable @{Path=$evtx.FullName; Level=1,2} -MaxEvents 500 -ErrorAction Stop) } catch {}
        
        if ($evtx.Name -match "(?i)AAD.*Operational") {
            try { $events += @(Get-WinEvent -Path $evtx.FullName -ErrorAction Stop | Where-Object { $_.Message -match "(0x80072f8f|0xcaa7000f)" }) | Select-Object -Unique } catch {}
        }
        
        # Catch LOB and Store Apps native MDM Event Viewer logs (IDs 1920 - 1927) and dynamically extract IDs
        if ($evtx.Name -match "(?i)DeviceManagement-Enterprise-Diagnostics-Provider") {
            try {
                $mdmApps = Get-WinEvent -Path $evtx.FullName -ErrorAction Stop | Where-Object { $_.Id -match "^(1920|1921|1922|1923|1924|1925|1926|1927)$" }
                foreach ($appEvt in $mdmApps) {
                    $st = if ($appEvt.Id -match "1922|1923") { "Failed" } elseif ($appEvt.Id -match "1924|1926|1927") { "Success" } else { "Info" }
                    
                    $extractedId = "LOB/Store App"
                    if ($appEvt.Message -match "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})") {
                        $extractedId = $Matches[1]
                    } elseif ($appEvt.Message -match "PackageFamilyName:\s*([a-zA-Z0-9\.\_]+)" -and $Matches[1] -ne "(null)") {
                        $extractedId = $Matches[1]
                    } elseif ($appEvt.Message -match "ProductCode:\s*(\{.*?\})") {
                        $extractedId = $Matches[1]
                    } elseif ($appEvt.Message -match "MSI\s+([^\s]+)") {
                        $extractedId = "MSI: " + $Matches[1]
                    }

                    $safeMsg = Get-SafeHtml $appEvt.Message
                    $apps += [PSCustomObject]@{ Time=$appEvt.TimeCreated.ToString("HH:mm:ss"); Component="MDM Event ($($appEvt.Id))"; Status=$st; AppID=$extractedId; Message=$safeMsg }
                }
            } catch {}
        }

        # Catch Windows Hello for Business & PRT Provisioning Errors
        if ($evtx.Name -match "(?i)User Device Registration.*Admin") {
            try {
                $udrEvents = Get-WinEvent -Path $evtx.FullName -ErrorAction Stop | Where-Object { $_.Id -match "^(300|358|360)$" }
                foreach ($udr in $udrEvents) {
                    $msg = $udr.Message.Replace("`n"," ").Replace("`r","")
                    $safeMsg = Get-SafeHtml $msg
                    $insight = Get-ErrorInsight -Msg $msg -Comp "WHfB Registration"
                    $errors += [PSCustomObject]@{ Time=$udr.TimeCreated.ToString("HH:mm:ss"); Component="User Device Registration ($($udr.Id))"; Severity="OS ERROR"; Message=$safeMsg; Insight=$insight }
                }
            } catch {}
        }

        foreach ($event in $events) {
            $msg = if ($event.Message) { $event.Message.Replace("`n"," ").Replace("`r","") } else { "Event ID: $($event.Id)" }
            $safeMsg = Get-SafeHtml $msg
            $insight = Get-ErrorInsight -Msg $msg -Comp $event.ProviderName
            $errors += [PSCustomObject]@{ Time=$event.TimeCreated.ToString("HH:mm:ss"); Component=$event.ProviderName; Severity="OS ERROR"; Message=$safeMsg; Insight=$insight }
        }
    }
}

# --- PHASE 4: INTERACTIVE HTML DASHBOARD ---
Write-Host "-> Rendering Interactive Dashboard..." -ForegroundColor Cyan

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
h1, h2 { color: #f8fafc; font-weight: 600; display: inline-block; margin-bottom: 5px; }
.header { border-bottom: 1px solid #334155; padding-bottom: 20px; margin-bottom: 30px; }
.hud-container { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-bottom: 40px; }
.hud-card { background: #1e293b; padding: 25px; border-radius: 8px; border-top: 4px solid #38bdf8; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
.hud-card.danger { border-top-color: #f43f5e; }
.hud-value { font-size: 1.5em; font-weight: 700; word-break: break-all; margin-bottom: 8px; }
.hud-label { font-size: 0.85em; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.05em; }
.search-bar { width: 100%; padding: 12px; margin-bottom: 15px; margin-top: 10px; background: #1e293b; border: 1px solid #334155; color: #fff; border-radius: 6px; box-sizing: border-box; }
table { width: 100%; border-collapse: collapse; background: #1e293b; border-radius: 8px; overflow: hidden; margin
