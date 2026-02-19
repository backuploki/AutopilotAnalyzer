# Get the current module location
$moduleRoot = $PSScriptRoot

# Import all "Private" (Internal) Functions first
Get-ChildItem -Path "$moduleRoot\Private\*.ps1" | ForEach-Object {
    . $_.FullName
}

# Import all "Public" (User-Facing) Functions next
Get-ChildItem -Path "$moduleRoot\Public\*.ps1" | ForEach-Object {
    . $_.FullName
}
