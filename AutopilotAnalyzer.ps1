# --- PHASE 2: STATE ANALYSIS ---
Write-Host "-> Parsing Diagnostics & Payloads..." -ForegroundColor Cyan

# 1. Check Standard XML Diagnostic Report
$xmlFile = Get-ChildItem -Path $workDir -Filter "*.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($xmlFile) {
    [xml]$x = Get-Content $xmlFile.FullName
    $root = if ($x.DiagReport) { $x.DiagReport } elseif ($x.MDMEnterpriseDiagnosticsReport) { $x.MDMEnterpriseDiagnosticsReport }
    if ($root) {
        if ($root.EnterpriseConfiguration.TenantId) { $telemetry.TenantId = $root.EnterpriseConfiguration.TenantId }
        if ($root.DeviceVariables.OSVersion) { $telemetry.OSVersion = $root.DeviceVariables.OSVersion }
        if ($root.DeviceVariables.UserUPN) { $telemetry.UPN = $root.DeviceVariables.UserUPN }
        # Try XML first, though it may be blank post-OOBE
        if ($root.EnterpriseConfiguration.AutopilotProfileName -and $telemetry.Profile -eq "Unknown") { 
            $telemetry.Profile = $root.EnterpriseConfiguration.AutopilotProfileName 
        }
    }
}

# 2. Check Autopilot JSON Payload (Primary Source of Truth from Intune)
if ($telemetry.Profile -eq "Unknown") {
    $jsonFile = Get-ChildItem -Path $workDir -Filter "AutopilotDDSZTDFile.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($jsonFile) {
        try {
            $apJson = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            if ($apJson.ZtdProfileName) { 
                $telemetry.Profile = $apJson.ZtdProfileName 
            }
        } catch {
            Write-Warning "Could not parse AutopilotDDSZTDFile.json"
        }
    }
}
