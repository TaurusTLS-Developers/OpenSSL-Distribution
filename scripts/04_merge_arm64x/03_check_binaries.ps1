<#
.SYNOPSIS
    Job: 2c_merge-windows-arm64x | Step: 5 (Check for Windows Binaries to Sign)
#>
[CmdletBinding()]
param(
    [string]$Folder = (Join-Path ($env:GITHUB_WORKSPACE ?? $PWD.Path) "raw_shared\dist")
)

$ErrorActionPreference = 'Stop'

$commonDir = $env:COMMON_SCRIPTS_DIR ?? (Join-Path ($env:GITHUB_WORKSPACE ?? $PWD.Path) "scripts\common")

& "$commonDir\check_binaries.ps1" -Folder $Folder -Filter @("*.exe", "*.dll")