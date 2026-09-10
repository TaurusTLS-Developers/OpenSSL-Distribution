<#
.SYNOPSIS
    Verifies Microsoft Authenticode digital signatures on binaries.
.PARAMETER Folder
    The directory containing signed binaries.
.PARAMETER Filter
    File filter patterns (defaults to *.exe, *.dll).
.PARAMETER Recurse
    Whether to search recursively (default $true).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Folder,
    [string[]]$Filter = @("*.exe", "*.dll"),
    [switch]$Recurse = $true
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Folder)) {
    Write-Error "[VERIFY-SIG] Folder not found: '$Folder'"
    exit 1
}

$files = if ($Recurse) {
    Get-ChildItem -Path $Folder -Recurse -Include $Filter -File
} else {
    Get-ChildItem -Path $Folder -Include $Filter -File
}

if ($files.Count -eq 0) {
    Write-Host "[VERIFY-SIG] No binary files found to verify in '$Folder'."
    exit 0
}

Write-Host "[VERIFY-SIG] Verifying $($files.Count) binary file(s) in '$Folder'..."
$failed = $false

foreach ($file in $files) {
    Write-Host "Verifying $($file.FullName)..."
    $sig = Get-AuthenticodeSignature -FilePath $file.FullName
    Write-Host "  Status       : $($sig.Status)"
    Write-Host "  StatusMessage: $($sig.StatusMessage)"
    if ($sig.SignerCertificate) {
        Write-Host "  Subject      : $($sig.SignerCertificate.Subject)"
        Write-Host "  Issuer       : $($sig.SignerCertificate.Issuer)"
    }
    if ($sig.Status -ne 'Valid') {
        Write-Error "[VERIFY-SIG] Signature verification FAILED on $($file.Name): $($sig.Status)"
        $failed = $true
    }
}

if ($failed) {
    Write-Error "[VERIFY-SIG] One or more binary signatures are invalid!"
    exit 1
}

Write-Host "[VERIFY-SIG] ✅ All $($files.Count) files have valid digital signatures."
