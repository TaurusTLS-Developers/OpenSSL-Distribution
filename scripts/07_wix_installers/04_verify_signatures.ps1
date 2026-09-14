<#
.SYNOPSIS
    Job: 07_wix_installers | Verify Signed MSI
#>
[CmdletBinding()]
param(
    [string]$Folder = ($env:INSTALLERS_DIR ?? (Join-Path $PWD.Path "installers"))
)

$ErrorActionPreference = 'Stop'

try {
    & "$env:COMMON_SCRIPTS_DIR\verify_signatures.ps1" -Folder $Folder -Filter @("*.msi") -Recurse:$false
}
catch {
    Write-Error "Failed to verify signed MSI: $($_.Exception.Message)"
    exit 1
}