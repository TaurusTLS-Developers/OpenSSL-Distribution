<#
.SYNOPSIS
    Stages multi-architecture Windows redistributables (x64, x86, arm64) into redist/ for installer packing.
.PARAMETER RedistDir
    Destination root directory for staged redistributables.
.PARAMETER RawSharedX64Dir
    Directory containing staged x64 shared binaries.
.PARAMETER RawSharedX86Dir
    Directory containing staged x86 shared binaries.
.PARAMETER RawSharedArm64Dir
    Directory containing staged arm64 shared binaries.
.PARAMETER CommonAssetsDir
    Directory containing common assets (LICENSE.txt, LICENSE.rtf).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RedistDir,
    [Parameter(Mandatory=$true)]
    [string]$RawSharedX64Dir,
    [Parameter(Mandatory=$true)]
    [string]$RawSharedX86Dir,
    [Parameter(Mandatory=$true)]
    [string]$RawSharedArm64Dir,
    [Parameter(Mandatory=$true)]
    [string]$CommonAssetsDir,
    [string]$AssetsDir = ""
)

$ErrorActionPreference = 'Stop'

Write-Host "[STAGE-REDIST] Staging multi-arch redistributables into: $RedistDir"

$archMap = @{
    'x64'   = $RawSharedX64Dir
    'x86'   = $RawSharedX86Dir
    'arm64' = $RawSharedArm64Dir
}

foreach ($arch in @('x64', 'x86', 'arm64')) {
    $archDir = Join-Path $RedistDir $arch
    New-Item -ItemType Directory -Force -Path $archDir, "$archDir\providers", "$archDir\engines" | Out-Null
    $src = $archMap[$arch]

    if (-not (Test-Path $src)) {
        Write-Error "[STAGE-REDIST] Source folder for $arch not found at: '$src'"
        exit 1
    }

    Copy-Item "$src\openssl.exe" $archDir -ErrorAction SilentlyContinue
    Get-ChildItem $src -Filter 'libcrypto-*.dll' | Copy-Item -Destination $archDir
    Get-ChildItem $src -Filter 'libssl-*.dll'    | Copy-Item -Destination $archDir

    if (Test-Path "$src\providers") {
        Get-ChildItem "$src\providers" -Filter '*.dll' | Copy-Item -Destination "$archDir\providers"
    }
    if (Test-Path "$src\engines") {
        Get-ChildItem "$src\engines" -Filter '*.dll' | Copy-Item -Destination "$archDir\engines"
    }
}

if (Test-Path "$CommonAssetsDir\LICENSE.txt") {
    Copy-Item "$CommonAssetsDir\LICENSE.txt" $RedistDir -Force
}

if (Test-Path "$CommonAssetsDir\LICENSE.rtf" -and $AssetsDir -ne "") {
    New-Item -ItemType Directory -Force -Path $AssetsDir | Out-Null
    Copy-Item "$CommonAssetsDir\LICENSE.rtf" $AssetsDir -Force
}

Write-Host "[STAGE-REDIST] ✅ Multi-architecture redistributables successfully staged."
Get-ChildItem $RedistDir -Recurse | Select-Object -ExpandProperty FullName
