<#
.SYNOPSIS
    Job: 3a_innosetup-windows-installer | Step: 2 (Validate Signing Secrets)
#>
[CmdletBinding()]
param(
    [switch]$AllowMissingIfLocal
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\validate_azure_secrets.ps1" -AllowMissingIfLocal:$AllowMissingIfLocal
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
