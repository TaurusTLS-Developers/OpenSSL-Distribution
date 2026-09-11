<#
.SYNOPSIS
    Job: 2_compile-binaries | Step: 9 (Verify Signed Windows Binaries)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\raw_artifact\dist"
)

$ErrorActionPreference = 'Stop'

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    & "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.exe", "*.dll") -Recurse
}
catch {
    Write-Error "Failed to verify signed Windows binaries: $($_.Exception.Message)"
    exit 1
}
