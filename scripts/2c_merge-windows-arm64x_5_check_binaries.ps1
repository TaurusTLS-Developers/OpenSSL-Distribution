<#
.SYNOPSIS
    Job: 2c_merge-windows-arm64x | Step: 5 (Check for Windows Binaries to Sign)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\raw_shared\dist"
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\check_binaries.ps1" -Folder $Folder -Filter @("*.exe", "*.dll")
