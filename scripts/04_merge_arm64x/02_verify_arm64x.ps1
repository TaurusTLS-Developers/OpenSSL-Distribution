<#
.SYNOPSIS
    Job: 2c_merge-windows-arm64x | Step: 4 (Recursive Deep Verification of All ARM64X Binaries)
    Validates openssl.exe native ARM64 architecture and every DLL for AA64 and DVRT table.
.PARAMETER DistDir
    Directory containing shared binaries to verify (defaults to raw_shared\dist).
#>
[CmdletBinding()]
param(
    [string]$DistDir
)

$ErrorActionPreference = 'Stop'

$dist = if ($DistDir) { $DistDir } elseif ($env:GITHUB_WORKSPACE) { "$env:GITHUB_WORKSPACE\raw_shared\dist" } else { "$PWD\raw_shared\dist" }

# Locate dumpbin.exe
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath  = & $vswhere -latest -property installationPath
$dumpbin = Get-ChildItem "$vsPath\VC\Tools\MSVC" -Recurse -Filter "dumpbin.exe" |
    Where-Object { $_.FullName -match 'Hostx64\\x64' } | Select-Object -ExpandProperty FullName -First 1

Write-Host "[VERIFY-ARM64X] Using Dumpbin    : $dumpbin"
Write-Host "[VERIFY-ARM64X] Inspecting Folder: $dist"

if (-not (Test-Path $dist)) {
    throw "Target verification directory '$dist' does not exist!"
}

# 1. Verify openssl.exe is Pure Native ARM64 (AA64)
$exePath = "$dist\openssl.exe"
Write-Host "`n=== Checking openssl.exe: $exePath ==="
if (-not (Test-Path $exePath)) {
    throw "openssl.exe not found at $exePath!"
}

$exeHeaders = & $dumpbin /headers $exePath | Out-String
Write-Host "--- dumpbin /headers openssl.exe output ---"
Write-Host $exeHeaders

$isNativeArm64 = $exeHeaders -match "(?i)AA64\s+machine\s+\(ARM64\)" -or $exeHeaders -match "(?i)machine\s+\(ARM64\)"
Write-Host "Comparison: Pattern='AA64 machine (ARM64)' | Matched=$isNativeArm64"

if (-not $isNativeArm64) {
    throw "openssl.exe failed verification: Output does not match Native ARM64 (AA64)!"
}
Write-Host "✅ openssl.exe is confirmed Native ARM64"

# 2. Recursively verify EVERY DLL in dist/, providers/, and engines/
$allDlls = Get-ChildItem $dist -Recurse -Filter "*.dll"
if ($allDlls.Count -eq 0) { throw "No DLLs found in $dist directory!" }

Write-Host "`n=== Recursively Verifying All ($($allDlls.Count)) DLLs for ARM64X ==="
$failed = $false

foreach ($dll in $allDlls) {
    $relPath = $dll.FullName.Substring($dist.Length + 1)
    Write-Host "`n[+] Inspecting: $relPath"

    $headers    = & $dumpbin /headers $dll.FullName | Out-String
    $loadConfig = & $dumpbin /loadconfig $dll.FullName | Out-String

    Write-Host "--- dumpbin machine line ($relPath) ---"
    Write-Host ($headers | Select-String "machine").Line

    $isArm64Header = $headers -match "(?i)AA64\s+machine\s+\(ARM64\)" -or $headers -match "(?i)machine\s+\(.*ARM64.*\)"
    $hasDvrt = $loadConfig -match "(?i)Dynamic Value Relocation Table" -or $loadConfig -match "(?i)ARM64X"

    Write-Host "  -> Comparison: Base ARM64 Header=$isArm64Header | DVRT Table=$hasDvrt"

    if (-not $isArm64Header) {
        Write-Error "FAILED: $relPath is not an ARM64-based PE binary!"
        $failed = $true
    } elseif (-not $hasDvrt) {
        Write-Error "FAILED: $relPath is missing the Dynamic Value Relocation Table (EC slice not embedded)!"
        $failed = $true
    } else {
        Write-Host "    -> Verified: True ARM64X dual-architecture binary."
    }
}

if ($failed) {
    throw "ARM64X verification failed! One or more DLLs do not contain true dual-architecture payloads."
}

Write-Host "`n🎉 ALL $($allDlls.Count) DLLs (Core, Providers, Engines) are verified TRUE ARM64X binaries!"
