<#
.SYNOPSIS
    Job: 3c_wix-windows-installers | Step: 8 (Build MSI with WiX)
.PARAMETER Version
    OpenSSL release version string (e.g. 3.4.0).
.PARAMETER MajorMinor
    OpenSSL major.minor version.
.PARAMETER Arch
    Target architecture (x64, x86, arm64).
.PARAMETER WixArch
    WiX architecture flag (x64, x86, arm64).
.PARAMETER PfFolder
    Program Files folder identifier (ProgramFiles64Folder / ProgramFilesFolder).
.PARAMETER RedistDir
    Directory containing staged redistributables.
.PARAMETER OutputDir
    Destination directory for compiled MSI installer.
.PARAMETER AssetsDir
    Directory containing assets (banner, dialog, icon, license.rtf).
.PARAMETER PublisherName
    Publisher name to embed in MSI metadata.
.PARAMETER PublisherUrl
    Publisher URL to embed in MSI metadata.
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
    [string]$WixArch,
    [Parameter(Mandatory=$true)]
    [string]$PfFolder,
    [string]$RedistDir,
    [string]$OutputDir,
    [string]$AssetsDir,
    [string]$TemplatePath,
    [string]$PublisherName = "TaurusTLS Developers",
    [string]$PublisherUrl  = "https://github.com/TaurusTLS-Developers/OpenSSL-Distribution"
)

$ErrorActionPreference = 'Stop'

$wsDir = if ($env:GITHUB_WORKSPACE) { $env:GITHUB_WORKSPACE } else { $PWD.Path }
if (-not $RedistDir)    { $RedistDir    = Join-Path $wsDir "redist" }
if (-not $OutputDir)    { $OutputDir    = Join-Path $wsDir "installers" }
if (-not $AssetsDir)    { $AssetsDir    = Join-Path $wsDir "assets" }
if (-not $TemplatePath) { $TemplatePath = Join-Path $wsDir "config\openssl.wxs.template" }

$parts       = $Version -split '\.'
$fourPartVer = "$($parts[0]).$($parts[1]).$($parts[2]).0"

# Deterministic UpgradeCode per (Major.Minor + Architecture)
$bytes       = [System.Text.Encoding]::UTF8.GetBytes("taurustls.openssl.wix.$MajorMinor.$Arch")
$hash        = [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
$upgradeCode = [System.Guid]::new($hash).ToString().ToUpper()

Write-Host "[BUILD-WIX] Building WiX MSI Package for $Arch..."
Write-Host "  Version      : $Version ($fourPartVer)"
Write-Host "  UpgradeCode  : $upgradeCode"
Write-Host "  ProgramFiles : $PfFolder"
Write-Host "  Redist Dir   : $RedistDir"
Write-Host "  Output Dir   : $OutputDir"

# 1. Install / Verify WiX Toolset v5
$wixCmd = Get-Command wix.exe -ErrorAction SilentlyContinue
if (-not $wixCmd) {
    Write-Host "[BUILD-WIX] Installing WiX Toolset v5 via dotnet tool..."
    dotnet tool install --global wix --version 5.0.2
    wix extension add --global WixToolset.UI.wixext/5.0.2
}

# 2. Populate openssl.wxs from template
if (-not (Test-Path $TemplatePath)) {
    throw "WiX template not found at '$TemplatePath'!"
}

$wxs = Get-Content $TemplatePath -Raw
$wxs = $wxs.Replace('{{VERSION}}', $Version)
$wxs = $wxs.Replace('{{VERSION_FOUR_PART}}', $fourPartVer)
$wxs = $wxs.Replace('{{MAJOR_MINOR}}', $MajorMinor)
$wxs = $wxs.Replace('{{ARCH}}', $Arch)
$wxs = $wxs.Replace('{{UPGRADE_CODE}}', $upgradeCode)
$wxs = $wxs.Replace('{{PROGRAM_FILES_FOLDER}}', $PfFolder)
$wxs = $wxs.Replace('{{APP_PUBLISHER}}', $PublisherName)
$wxs = $wxs.Replace('{{APP_PUBLISHER_URL}}', $PublisherUrl)
$wxs = $wxs.Replace('{{REDIST_DIR}}', $RedistDir)
$wxs = $wxs.Replace('{{ASSETS_DIR}}', $AssetsDir)

$wxsPath = Join-Path $wsDir "openssl.wxs"
[System.IO.File]::WriteAllText($wxsPath, $wxs, [System.Text.UTF8Encoding]::new($false))

# 3. Build MSI
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$msiOut = Join-Path $OutputDir "openssl-$Version-Windows-$Arch.msi"

Write-Host "[BUILD-WIX] Compiling MSI via wix build: $msiOut"
wix build $wxsPath -arch $WixArch -ext WixToolset.UI.wixext -o $msiOut
if ($LASTEXITCODE -ne 0) { throw "WiX build failed with exit code $LASTEXITCODE" }

Write-Host "[BUILD-WIX] ✅ MSI Created successfully: '$msiOut'"
