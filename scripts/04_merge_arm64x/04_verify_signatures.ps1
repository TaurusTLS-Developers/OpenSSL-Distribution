<#
.SYNOPSIS
    Job: 2c_merge-windows-arm64x | Step: 8 (Verify Signed Windows ARM64X Binaries)
#>
[CmdletBinding()]
param(
    [string]$Folder = ($env:DIST_SHARED ?? (Join-Path ($env:GITHUB_WORKSPACE ?? $PWD.Path) "raw_artifact\dist"))
)

$ErrorActionPreference = 'Stop'

try {
    & "$env:COMMON_SCRIPTS_DIR\verify_signatures.ps1" -Folder $Folder -Filter @("*.exe", "*.dll") -Recurse:$true
}
catch {
    Write-Error "Failed to verify signed binaries: $($_.Exception.Message)"
    exit 1
}