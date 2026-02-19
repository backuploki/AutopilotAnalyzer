function New-AutopilotReport {
    param($State, $Errors, $Apps)
    
    # CSS Styles (Minified for brevity)
    $css = "body{font-family:'Segoe UI',sans-serif;background:#121212;color:#e0e0e0;padding:20px}.header{border-bottom:2px solid #00e5ff;padding-bottom:20px;margin-bottom:30px}h1{color:#00e5ff;text-transform:uppercase}.hud-container{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:20px;margin-bottom:40px}.hud-card{background:#1e1e1e;padding:20px;border-left:4px solid #00e5ff}.hud-card.danger{border-left-color:#ff4081}.hud-value{font-size:2.5em;font-weight:bold}table{width:100%;border-collapse:collapse;background:#1e1e1e}th{background:#2c2c2c;padding:15px;color:#00e5ff;text-align:left}td{padding:12px 15px;border-bottom:1px solid #333}.status-Success{color:#00e5ff}.status-Failed{color:#ff4081}"
    
    # Generate HTML Tables
    $errTable = if ($Errors) { 
        $rows = $Errors | ForEach-Object { "<tr><td>$($_.Time)</td><td style='color:#ff4081'>$($_.Severity)</td><td>$($_.Component)</td><td>$($_.Message)</td></tr>" }
        "<table><tr><th>Time</th><th>Severity</th><th>Component</th><th>Message</th></tr>$rows</table>" 
    } else { "<p>No Critical Errors.</p>" }
    
    $appTable = if ($Apps) {
        $rows = $Apps | ForEach-Object { "<tr><td>$($_.Time)</td><td>$($_.Component)</td><td class='status-$($_.Status)'>$($_.Status)</td><td>$($_.Message)</td></tr>" }
        "<table><tr><th>Time</th><th>Component</th><th>Status</th><th>Message</th></tr>$rows</table>"
    } else { "<p>No App Telemetry.</p>" }

    $reportPath = Join-Path -Path $env:TEMP -ChildPath "Autopilot_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    
    $html = "<!DOCTYPE html><html><head><title>Report</title><style>$css</style></head><body><div class='header'><h1>Autopilot Diagnostic System</h1></div><div class='hud-container'><div class='hud-card $(if($Errors){'danger'})'><div class='hud-value'>$($Errors.Count)</div><div>Critical Failures</div></div><div class='hud-card'><div class='hud-value'>$($Apps.Count)</div><div>Events Tracked</div></div><div class='hud-card'><div class='hud-value'>$($State.TenantId)</div><div>Tenant ID</div></div></div><h2>Critical Failures</h2>$errTable<h2>App Telemetry</h2>$appTable</body></html>"
    
    $html | Out-File -FilePath $reportPath -Encoding utf8
    return $reportPath
}
