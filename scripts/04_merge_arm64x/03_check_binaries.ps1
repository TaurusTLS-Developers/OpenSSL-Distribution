<#
.SYNOPSIS
    Job: 2c_merge-windows-arm64x | Step: 5 (Check for Windows Binaries to Sign)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\raw_shared\dist"
)

$ErrorActionPreference = 'Stop'

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    & "$scriptDir\common\check_binaries.ps1" -Folder $Folder -Filter @("*.exe", "*.dll")
}
catch {
    Write-Error "Failed to check for Windows binaries for signing: $($_.Exception.Message)"
    exit 1
}
