<#
.SYNOPSIS
    Job: 2_compile-binaries | Step: 9 (Verify Signed Windows Binaries)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\raw_artifact\dist"
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.exe", "*.dll") -Recurse
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
