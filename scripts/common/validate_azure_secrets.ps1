<#
.SYNOPSIS
    Validates Azure Trusted Signing environment variables.
.DESCRIPTION
    Checks presence of AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID,
    AZURE_SUBSCRIPTION_ID, AZURE_SIGNING_ACCOUNT_NAME, AZURE_CERTIFICATE_PROFILE_NAME,
    and optionally AZURE_MSIX_PUBLISHER.
.PARAMETER RequireMsixPublisher
    Switch to mandate AZURE_MSIX_PUBLISHER for MSIX packaging.
.PARAMETER AllowMissingIfLocal
    Switch to issue a warning and return $false instead of throwing if running locally without credentials.
#>
[CmdletBinding()]
param(
    [switch]$RequireMsixPublisher,
    [switch]$AllowMissingIfLocal
)

$ErrorActionPreference = 'Stop'

$requiredVars = @(
    "AZURE_CLIENT_ID",
    "AZURE_CLIENT_SECRET",
    "AZURE_TENANT_ID",
    "AZURE_SUBSCRIPTION_ID",
    "AZURE_SIGNING_ACCOUNT_NAME",
    "AZURE_CERTIFICATE_PROFILE_NAME"
)

if ($RequireMsixPublisher) {
    $requiredVars += "AZURE_MSIX_PUBLISHER"
}

$missing = @()
foreach ($varName in $requiredVars) {
    $val = [System.Environment]::GetEnvironmentVariable($varName)
    if ([string]::IsNullOrWhiteSpace($val)) {
        $missing += $varName
    }
}

if ($missing.Count -gt 0) {
    $msg = "Required Azure Code Signing secret(s) missing: $($missing -join ', ')"
    if ($AllowMissingIfLocal -or -not $env:GITHUB_ACTIONS) {
        Write-Warning "[SIGNING-VALIDATION] $msg (Proceeding without signing in local development mode)."
        return $false
    } else {
        Write-Error "[SIGNING-VALIDATION] FATAL: $msg"
        exit 1
    }
}

Write-Host "[SIGNING-VALIDATION] All required Azure Trusted Signing secrets are verified."
return $true
