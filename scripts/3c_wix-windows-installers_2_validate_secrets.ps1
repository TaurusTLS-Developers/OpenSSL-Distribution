<#
.SYNOPSIS
    Job: 3c_wix-windows-installers | Step: 2 (Validate Signing Secrets)
#>
[CmdletBinding()]
param(
    [switch]$AllowMissingIfLocal
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\validate_azure_secrets.ps1" -AllowMissingIfLocal:$AllowMissingIfLocal
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
