<#
.SYNOPSIS
    Job: 2c_merge-windows-arm64x | Step: 8 (Verify Signed Windows ARM64X Binaries)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\raw_shared\dist"
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.exe", "*.dll") -Recurse
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
