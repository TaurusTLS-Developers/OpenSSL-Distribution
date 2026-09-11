<#
.SYNOPSIS
    Job: 2_compile-binaries | Step: 3 (Validate Azure Code Signing Secrets)
#>
[CmdletBinding()]
param(
    [switch]$AllowMissingIfLocal
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\validate_azure_secrets.ps1" -AllowMissingIfLocal:$AllowMissingIfLocal
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
