<#
.SYNOPSIS
    Job: 3b_msix-windows-installers | Step: 8 (Verify Signed MSIX Package)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\installers"
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.msix") -Recurse:$false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
