<#
.SYNOPSIS
    Job: 2_compile-binaries | Step: 3 (Validate Azure Code Signing Secrets)
#>
[CmdletBinding()]
param([switch]$AllowMissingIfLocal)
$ErrorActionPreference = 'Stop'

& "$env:COMMON_SCRIPTS_DIR\validate_azure_secrets.ps1" -AllowMissingIfLocal:$AllowMissingIfLocal