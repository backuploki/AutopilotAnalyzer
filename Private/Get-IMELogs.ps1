function Get-IMELogs {
    param([string]$WorkDir)
    $logFile = Get-ChildItem -Path $WorkDir -Filter "IntuneManagementExtension.log" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $results = @{ Errors = @(); Apps = @() }
    
    if ($logFile) {
        $regex = '<!\[LOG\[(?<Message>.*?)\]LOG\]!><time="(?<Time>.*?)" date="(?<Date>.*?)" component="(?<Component>.*?)" context=".*?" type="(?<Type>.*?)"'
        foreach ($line in [System.IO.File]::ReadLines($logFile.FullName)) {
            if ($line -match $regex) {
                $m = $Matches
                if ($m.Type -eq "3" -or $m.Message -match "(?i)fail|error|timeout|exitcode") {
                    $results.Errors += [PSCustomObject]@{ Time=$m.Time; Component=$m.Component; Severity="CRITICAL"; Message=$m.Message }
                }
                if ($m.Component -match "(?i)AppWorkload|AgentExecutor") {
                    if ($m.Message -match "(?i)Downloading|Installing|Enforcing|ExitCode") {
                        $status = if ($m.Message -match "ExitCode.*0") { "Success" } elseif ($m.Message -match "ExitCode") { "Failed" } else { "Info" }
                        $results.Apps += [PSCustomObject]@{ Time=$m.Time; Component=$m.Component; Status=$status; Message=$m.Message }
                    }
                }
            }
        }
    }
    return $results
}
