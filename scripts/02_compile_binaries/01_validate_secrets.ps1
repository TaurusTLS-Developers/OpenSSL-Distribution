<#
.SYNOPSIS
    Job: 2_compile-binaries | Step: 3 (Validate Azure Code Signing Secrets)
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
