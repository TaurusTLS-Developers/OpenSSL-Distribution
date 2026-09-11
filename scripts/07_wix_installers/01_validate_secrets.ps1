<#
.SYNOPSIS
    Job: 3c_wix-windows-installers | Step: 2 (Validate Signing Secrets)
#>
[CmdletBinding()]
param(
    [switch]$AllowMissingIfLocal
)

$ErrorActionPreference = 'Stop'

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    & "$scriptDir\common\validate_azure_secrets.ps1" -AllowMissingIfLocal:$AllowMissingIfLocal
}
catch {
    Write-Error "Azure Signiture secrets validation failed: $($_.Exception.Message)"
    exit 1
}
