function Invoke-AutopilotAnalyzer {
    <#
    .SYNOPSIS
        The main controller for the Autopilot Analyzer module.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$LogPath
    )

    Write-Host "[ Autopilot Analyzer v2.0 ]" -ForegroundColor Cyan
    
    # Phase 1: Ingest
    $workDir = Expand-LogArchive -Path $LogPath
    
    try {
        # Phase 2: Analyze State
        Write-Host "-> Analyzing Provisioning State..." -ForegroundColor Yellow
        $state = Get-MDMState -WorkDir $workDir
        
        # Phase 3: Analyze Logs
        Write-Host "-> Parsing IME Logs..." -ForegroundColor Yellow
        $logs = Get-IMELogs -WorkDir $workDir
        
        # Phase 4: Report
        Write-Host "-> Genering Report..." -ForegroundColor Yellow
        $report = New-AutopilotReport -State $state -Errors $logs.Errors -Apps $logs.Apps
        
        Invoke-Item $report
        Write-Host "[ COMPLETE ]" -ForegroundColor Green
    }
    finally {
        # Phase 5: Cleanup
        Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
