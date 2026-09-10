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
    [Parameter(Mandatory=$true)]
    [string]$Folder,
    [string[]]$Filter = @("*.exe", "*.dll")
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Folder)) {
    Write-Host "[CHECK-BINARIES] Folder '$Folder' does not exist."
    if ($env:GITHUB_OUTPUT) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "has_binaries=false"
    }
    return $false
}

$files = Get-ChildItem -Path $Folder -Recurse -Include $Filter -File
if ($files.Count -gt 0) {
    Write-Host "[CHECK-BINARIES] Found $($files.Count) binary file(s) in '$Folder'."
    if ($env:GITHUB_OUTPUT) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "has_binaries=true"
    }
    return $true
} else {
    Write-Host "[CHECK-BINARIES] No matching binary files found in '$Folder'."
    if ($env:GITHUB_OUTPUT) {
        Add-Content -Path $env:GITHUB_OUTPUT -Value "has_binaries=false"
    }
    return $false
}
