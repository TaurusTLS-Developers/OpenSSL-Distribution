<#
.SYNOPSIS
    Job: 05_innosetup_installer | Verify Signed InnoSetup Installer
#>
[CmdletBinding()]
param(
    [string]$Folder = ($env:INSTALLERS_DIR ?? (Join-Path $PWD.Path "installers"))
)

$ErrorActionPreference = 'Stop'

try {
    & "$env:COMMON_SCRIPTS_DIR\verify_signatures.ps1" -Folder $Folder -Filter @("*.exe") -Recurse:$false
}
catch {
    Write-Error "Failed to verify signed InnoSetup installer: $($_.Exception.Message)"
    exit 1
}