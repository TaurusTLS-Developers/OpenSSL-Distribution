<#
.SYNOPSIS
    Scans a folder for binaries to determine if digital signing is required.
.PARAMETER Folder
    The directory path to search.
.PARAMETER Filter
    File filter patterns (defaults to *.exe, *.dll).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Folder,

    [string[]]$Filter = @("*.exe", "*.dll")
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Folder)) {
    Write-Host "[CHECK-BINARIES] Directory does not exist: $Folder"
    $hasBinaries = "false"
} else {
    $files = Get-ChildItem -Path $Folder -Recurse -Include $Filter -File -ErrorAction SilentlyContinue
    if ($files.Count -gt 0) {
        Write-Host "[CHECK-BINARIES] Found $($files.Count) binary file(s) to sign in $Folder."
        $hasBinaries = "true"
    } else {
        Write-Host "[CHECK-BINARIES] No matching ($($Filter -join ', ')) files found in $Folder."
        $hasBinaries = "false"
    }
}

# Write to GITHUB_OUTPUT for CI, or print to console if running locally
if ($env:GITHUB_OUTPUT) {
    Add-Content -Path $env:GITHUB_OUTPUT -Value "has_binaries=$hasBinaries"
} else {
    Write-Host "[CHECK-BINARIES] (Local) Output: has_binaries=$hasBinaries"
}
