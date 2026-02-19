function Expand-LogArchive {
    param([string]$Path)
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $workDir = Join-Path -Path $env:TEMP -ChildPath "AutopilotAnalyzer_$timestamp"
    New-Item -Path $workDir -ItemType Directory -Force | Out-Null
    
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    if ($ext -eq '.zip') { Expand-Archive -Path $Path -DestinationPath $workDir -Force }
    elseif ($ext -eq '.cab') { 
        $args = "`"$Path`" -F:* `"$workDir`""
        Start-Process -FilePath "expand.exe" -ArgumentList $args -Wait -NoNewWindow
    }
    return $workDir
}
