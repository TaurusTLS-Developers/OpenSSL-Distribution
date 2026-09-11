<#
.SYNOPSIS
    Job: 3c_wix-windows-installers | Step: 11 (Verify Signed MSI)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\installers"
)

$ErrorActionPreference = 'Stop'

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    & "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.msi") -Recurse:$false
}
catch {
    Write-Error "Failed to verify signed MSI: $($_.Exception.Message)"
    exit 1
}
