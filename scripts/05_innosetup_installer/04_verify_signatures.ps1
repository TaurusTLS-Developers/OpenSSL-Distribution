<#
.SYNOPSIS
    Job: 3a_innosetup-windows-installer | Step: 12 (Verify Signed Installer)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\installers"
)

$ErrorActionPreference = 'Stop'

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    & "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.exe") -Recurse:$false
}
catch {
    Write-Error "Failed to verify signed installer: $($_.Exception.Message)"
    exit 1
}
