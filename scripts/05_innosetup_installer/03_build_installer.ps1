<#
.SYNOPSIS
    Job: 3a_innosetup-windows-installer | Step: 9 (Generate and Compile Multi-Arch Installer)
.PARAMETER Version
    OpenSSL release version string (e.g. 3.4.0).
.PARAMETER MajorMinor
    OpenSSL major.minor version.
.PARAMETER InnoAppId
    Deterministic InnoSetup AppId GUID.
.PARAMETER RedistDir
    Directory containing staged redistributables.
.PARAMETER OutputDir
    Destination directory for compiled setup executable.
.PARAMETER AssetsDir
    Directory containing visual branding assets.
.PARAMETER TemplatePath
    Path to config/openssl-installer.iss.template.
.PARAMETER PublisherName
    Publisher name to embed in installer metadata.
.PARAMETER PublisherUrl
    Publisher URL to embed in installer metadata.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [Parameter(Mandatory=$true)]
    [string]$MajorMinor,
    [Parameter(Mandatory=$true)]
    [string]$InnoAppId,
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
if (-not $TemplatePath) { $TemplatePath = Join-Path $wsDir "config\openssl-installer.iss.template" }

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$outFilename = "openssl-$Version-Windows-installer"

Write-Host "[BUILD-INNO] Generating and compiling InnoSetup multi-arch installer..."
Write-Host "  Version      : $Version"
Write-Host "  MajorMinor   : $MajorMinor"
Write-Host "  InnoAppId    : $InnoAppId"
Write-Host "  Redist Dir   : $RedistDir"
Write-Host "  Output Dir   : $OutputDir"
Write-Host "  Template     : $TemplatePath"

if (-not (Test-Path $TemplatePath)) {
    throw "InnoSetup template not found at '$TemplatePath'!"
}

$iss = Get-Content $TemplatePath -Raw
$iss = $iss.Replace('{{APP_ID}}', "{{$InnoAppId}")
$iss = $iss.Replace('{{VERSION}}', $Version)
$iss = $iss.Replace('{{MAJOR_MINOR}}', $MajorMinor)
$iss = $iss.Replace('{{APP_PUBLISHER}}', $PublisherName)
$iss = $iss.Replace('{{PUBLISHER_DISPLAY_NAME}}', $PublisherName)
$iss = $iss.Replace('{{APP_PUBLISHER_URL}}', $PublisherUrl)
$iss = $iss.Replace('{{OUTPUT_DIR}}', $OutputDir)
$iss = $iss.Replace('{{OUTPUT_BASE_FILENAME}}', $outFilename)
$iss = $iss.Replace('{{REDIST_DIR}}', $RedistDir)
$iss = $iss.Replace('{{ASSETS_DIR}}', $AssetsDir)

$issPath = Join-Path $wsDir "openssl-installer.iss"
[System.IO.File]::WriteAllText($issPath, $iss, [System.Text.UTF8Encoding]::new($false))

Write-Host "[BUILD-INNO] Generated InnoSetup script: '$issPath'"

# Locate ISCC.exe
$iscc = Get-ChildItem 'C:\Program Files (x86)\Inno Setup*' -Filter 'ISCC.exe' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName -First 1
if (-not $iscc) {
    $isccCmd = Get-Command iscc.exe -ErrorAction SilentlyContinue
    if ($isccCmd) { $iscc = $isccCmd.Source }
}
if (-not $iscc) { throw 'ISCC.exe not found on system! Install InnoSetup.' }

Write-Host "[BUILD-INNO] Compiling via: $iscc"
& $iscc $issPath
if ($LASTEXITCODE -ne 0) { throw "InnoSetup compilation failed with exit code $LASTEXITCODE" }

Write-Host "[BUILD-INNO] ✅ Multi-Arch InnoSetup installer successfully compiled: '$OutputDir\$outFilename.exe'"
