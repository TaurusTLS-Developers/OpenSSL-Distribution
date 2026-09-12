<#
.SYNOPSIS
    Job: 3a_innosetup-windows-installer | Step: 2 (Validate Signing Secrets)
#>
[CmdletBinding()]
param([switch]$AllowMissingIfLocal)
$ErrorActionPreference = 'Stop'

& "$env:COMMON_SCRIPTS_DIR\validate_azure_secrets.ps1" -AllowMissingIfLocal:$AllowMissingIfLocal