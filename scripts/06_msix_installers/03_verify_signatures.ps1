<#
.SYNOPSIS
    Job: 06_msix_installers | Verify Signed MSIX
#>
[CmdletBinding()]
param(
    [string]$Folder = ($env:INSTALLERS_DIR ?? (Join-Path $PWD.Path "installers"))
)

$ErrorActionPreference = 'Stop'

try {
    & "$env:COMMON_SCRIPTS_DIR\verify_signatures.ps1" -Folder $Folder -Filter @("*.msix") -Recurse:$false
}
catch {
    Write-Error "Failed to verify signed MSIX: $($_.Exception.Message)"
    exit 1
}