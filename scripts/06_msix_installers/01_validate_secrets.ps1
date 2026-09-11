<#
.SYNOPSIS
    Job: 3b_msix-windows-installers | Step: 2 (Validate Signing Secrets)
#>
[CmdletBinding()]
param(
    [switch]$AllowMissingIfLocal
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\validate_azure_secrets.ps1" -RequireMsixPublisher -AllowMissingIfLocal:$AllowMissingIfLocal
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
