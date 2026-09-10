<#
.SYNOPSIS
    Job: 2_compile-binaries | Step: 6 (Check for Windows Binaries to Sign)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\raw_artifact\dist"
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\check_binaries.ps1" -Folder $Folder -Filter @("*.exe", "*.dll")
