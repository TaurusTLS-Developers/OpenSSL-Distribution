<#
.SYNOPSIS
    Job: 3b_msix-windows-installers | Step: 5 (Build Framework MSIX Package)
.PARAMETER Version
    OpenSSL release version string (e.g. 3.4.0).
.PARAMETER MajorMinor
    OpenSSL major.minor version.
.PARAMETER Arch
    Target architecture (x64, x86, arm64).
.PARAMETER MsixArch
    MSIX architecture string (x64, x86, arm64).
.PARAMETER RawSharedDir
    Directory containing shared binaries for this architecture.
.PARAMETER CommonAssetsDir
    Directory containing common assets (LICENSE.txt).
.PARAMETER AssetsDir
    Directory containing MSIX assets (PNG icons).
.PARAMETER OutputDir
    Destination directory for generated .msix package.
.PARAMETER Publisher
    Azure MSIX publisher identity string.
.PARAMETER PublisherDisplayName
    Friendly display name for publisher.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [Parameter(Mandatory=$true)]
    [string]$MajorMinor,
    [Parameter(Mandatory=$true)]
    [string]$Arch,
    [Parameter(Mandatory=$true)]
    [string]$MsixArch,
    [string]$RawSharedDir,
    [string]$CommonAssetsDir,
    [string]$AssetsDir,
    [string]$OutputDir,
    [string]$TemplatePath,
    [string]$Publisher = "CN=TaurusTLS Developers",
    [string]$PublisherDisplayName = "TaurusTLS Developers"
)

$ErrorActionPreference = 'Stop'

$wsDir = if ($env:GITHUB_WORKSPACE) { $env:GITHUB_WORKSPACE } else { $PWD.Path }
if (-not $RawSharedDir)    { $RawSharedDir    = Join-Path $wsDir "raw-shared" }
if (-not $CommonAssetsDir) { $CommonAssetsDir = Join-Path $wsDir "common-assets" }
if (-not $AssetsDir)       { $AssetsDir       = Join-Path $wsDir "assets" }
if (-not $OutputDir)       { $OutputDir       = Join-Path $wsDir "installers" }
if (-not $TemplatePath)    { $TemplatePath    = Join-Path $wsDir "config\AppxManifest.xml.template" }

$staging = Join-Path $wsDir "msix-staging-$Arch"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

$parts   = $Version -split '\.'
$msixVer = "$($parts[0]).$($parts[1]).$($parts[2]).0"

Write-Host "[BUILD-MSIX] Building Framework MSIX Package for $Arch..."
Write-Host "  Version      : $Version ($msixVer)"
Write-Host "  Architecture : $Arch ($MsixArch)"
Write-Host "  Raw Shared   : $RawSharedDir"
Write-Host "  Staging Dir  : $staging"
Write-Host "  Output Dir   : $OutputDir"

# Locate MakeAppx.exe from Windows SDK
$makeAppx = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' `
    -Filter 'MakeAppx.exe' -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -match '\\x64$' } |
    Select-Object -ExpandProperty FullName -First 1
if (-not $makeAppx) {
    $makeAppxCmd = Get-Command MakeAppx.exe -ErrorAction SilentlyContinue
    if ($makeAppxCmd) { $makeAppx = $makeAppxCmd.Source }
}
if (-not $makeAppx) { throw 'MakeAppx.exe not found in Windows SDK!' }

New-Item -ItemType Directory -Force -Path "$staging\Assets", $OutputDir | Out-Null

if (Test-Path $AssetsDir) {
    Copy-Item -Recurse -Force "$AssetsDir\*" "$staging\Assets\"
} else {
    throw "Assets folder not found at '$AssetsDir'"
}

Copy-Item "$RawSharedDir\openssl.exe" $staging -ErrorAction SilentlyContinue
Get-ChildItem $RawSharedDir -Filter 'libcrypto-*.dll' | Copy-Item -Destination $staging
Get-ChildItem $RawSharedDir -Filter 'libssl-*.dll'    | Copy-Item -Destination $staging

if (Test-Path "$RawSharedDir\providers") {
    New-Item -ItemType Directory -Force -Path "$staging\providers" | Out-Null
    Get-ChildItem "$RawSharedDir\providers" -Filter '*.dll' | Copy-Item -Destination "$staging\providers"
}
if (Test-Path "$RawSharedDir\engines") {
    New-Item -ItemType Directory -Force -Path "$staging\engines" | Out-Null
    Get-ChildItem "$RawSharedDir\engines" -Filter '*.dll' | Copy-Item -Destination "$staging\engines"
}
if (Test-Path "$CommonAssetsDir\LICENSE.txt") {
    Copy-Item "$CommonAssetsDir\LICENSE.txt" $staging -Force
}

$xmlPublisher = [System.Security.SecurityElement]::Escape($Publisher)
$xmlPubName   = [System.Security.SecurityElement]::Escape($PublisherDisplayName)

if (-not (Test-Path $TemplatePath)) {
    throw "AppxManifest template not found at '$TemplatePath'!"
}

$xml = Get-Content $TemplatePath -Raw
$xml = $xml.Replace('{{MSIX_PUBLISHER}}', $xmlPublisher)
$xml = $xml.Replace('{{MSIX_VERSION}}', $msixVer)
$xml = $xml.Replace('{{MSIX_ARCH}}', $MsixArch)
$xml = $xml.Replace('{{VERSION}}', $Version)
$xml = $xml.Replace('{{MAJOR_MINOR}}', $MajorMinor)
$xml = $xml.Replace('{{ARCH}}', $Arch)
$xml = $xml.Replace('{{PUBLISHER_DISPLAY_NAME}}', $xmlPubName)

[System.IO.File]::WriteAllText("$staging\AppxManifest.xml", $xml, [System.Text.UTF8Encoding]::new($false))

$msixOut = Join-Path $OutputDir "openssl-$Version-Windows-$Arch.msix"
Write-Host "[BUILD-MSIX] Packing via MakeAppx: $msixOut"
& $makeAppx pack /d $staging /p $msixOut /o
if ($LASTEXITCODE -ne 0) { throw "MakeAppx pack failed for $Arch with exit code $LASTEXITCODE" }

Write-Host "[BUILD-MSIX] ✅ Framework MSIX created: '$msixOut'"
