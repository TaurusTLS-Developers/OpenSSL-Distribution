<#
.SYNOPSIS
    Job: 3c_wix-windows-installers | Step: 11 (Verify Signed MSI)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\installers"
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.msi") -Recurse:$false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
