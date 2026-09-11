<#
.SYNOPSIS
    Job: 2c_merge-windows-arm64x | Step: 8 (Verify Signed Windows ARM64X Binaries)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\raw_shared\dist"
)

$ErrorActionPreference = 'Stop'

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCo  mmand.Path
    & "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.exe", "*.dll") -Recurse
}
catch {
    Write-Error "Failed to verify signed Windows ARM64X binaries: $($_.Exception.Message)"
    exit 1
}
