<#
.SYNOPSIS
    Job: 3a_innosetup-windows-installer | Step: 12 (Verify Signed Installer)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\installers"
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.exe") -Recurse:$false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
