<#
.SYNOPSIS
    Job: 02_compile_binaries | Check for Windows Binaries to Sign
#>
[CmdletBinding()]
param(
    [string]$Folder = (Join-Path ($env:GITHUB_WORKSPACE ?? $PWD.Path) "raw_artifact\dist")
)

$ErrorActionPreference = 'Stop'

$commonDir = $env:COMMON_SCRIPTS_DIR ?? (Join-Path ($env:GITHUB_WORKSPACE ?? $PWD.Path) "scripts\common")

& "$commonDir\check_binaries.ps1" -Folder $Folder -Filter @("*.exe", "*.dll")