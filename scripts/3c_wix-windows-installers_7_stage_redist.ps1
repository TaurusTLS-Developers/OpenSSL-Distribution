<#
.SYNOPSIS
    Job: 3c_wix-windows-installers | Step: 7 (Stage Redistributables & Convert LICENSE to RTF)
#>
[CmdletBinding()]
param(
    [string]$WorkspaceDir,
    [string]$RedistDir,
    [string]$AssetsDir,
    [string]$RawSharedX64Dir,
    [string]$RawSharedX86Dir,
    [string]$RawSharedArm64Dir,
    [string]$CommonAssetsDir
)
$ws = if ($WorkspaceDir) { $WorkspaceDir } elseif ($env:GITHUB_WORKSPACE) { $env:GITHUB_WORKSPACE } else { $PWD.Path }
if (-not $RedistDir)         { $RedistDir         = Join-Path $ws "redist" }
if (-not $AssetsDir)         { $AssetsDir         = Join-Path $ws "assets" }
if (-not $RawSharedX64Dir)   { $RawSharedX64Dir   = Join-Path $ws "raw-shared-x64" }
if (-not $RawSharedX86Dir)   { $RawSharedX86Dir   = Join-Path $ws "raw-shared-x86" }
if (-not $RawSharedArm64Dir) { $RawSharedArm64Dir = Join-Path $ws "raw-shared-arm64" }
if (-not $CommonAssetsDir)   { $CommonAssetsDir   = Join-Path $ws "common-assets" }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\common\stage_windows_redist.ps1" `
    -RedistDir $RedistDir `
    -RawSharedX64Dir $RawSharedX64Dir `
    -RawSharedX86Dir $RawSharedX86Dir `
    -RawSharedArm64Dir $RawSharedArm64Dir `
    -CommonAssetsDir $CommonAssetsDir `
    -AssetsDir $AssetsDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
