function Get-MDMState {
    param([string]$WorkDir)
    $xmlFile = Get-ChildItem -Path $WorkDir -Filter "MDMDiagReport.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($xmlFile) {
        try {
            [xml]$mdm = Get-Content -Path $xmlFile.FullName
            $root = if ($mdm.DiagReport) { $mdm.DiagReport } else { $mdm.MDMEnterpriseDiagnosticsReport }
            return [PSCustomObject]@{
                TenantId   = $root.EnterpriseConfiguration.TenantId
                OSVersion  = $root.DeviceVariables.OSVersion
                ESPEnabled = if ($root.EnterpriseConfiguration.EnrollmentStatusPage) { $true } else { $false }
            }
        } catch { return $null }
    }
    return $null
}
