<#
.SYNOPSIS
    Job: 3b_msix-windows-installers | Step: 8 (Verify Signed MSIX Package)
#>
[CmdletBinding()]
param(
    [string]$Folder = "$PWD\installers"
)

$ErrorActionPreference = 'Stop'

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    & "$scriptDir\common\verify_signatures.ps1" -Folder $Folder -Filter @("*.msix") -Recurse:$false
}
catch {
    Write-Error "Failed to verify signed MSIX package: $($_.Exception.Message)"
    exit 1
}
