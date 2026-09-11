<#
.SYNOPSIS
    Job: 3a_innosetup-windows-installer | Step: 7 (Stage Multi-Arch Redistributables)
#>
[CmdletBinding()]
param(
    [string]$WorkspaceDir,
    [string]$RedistDir,
    [string]$RawSharedX64Dir,
    [string]$RawSharedX86Dir,
    [string]$RawSharedArm64Dir,
    [string]$CommonAssetsDir
)
$ws = if ($WorkspaceDir) { $WorkspaceDir } elseif ($env:GITHUB_WORKSPACE) { $env:GITHUB_WORKSPACE } else { $PWD.Path }
if (-not $RedistDir)         { $RedistDir         = Join-Path $ws "redist" }
if (-not $RawSharedX64Dir)   { $RawSharedX64Dir   = Join-Path $ws "raw-shared-x64" }
if (-not $RawSharedX86Dir)   { $RawSharedX86Dir   = Join-Path $ws "raw-shared-x86" }
if (-not $RawSharedArm64Dir) { $RawSharedArm64Dir = Join-Path $ws "raw-shared-arm64" }
if (-not $CommonAssetsDir)   { $CommonAssetsDir   = Join-Path $ws "common-assets" }

# To avoid invalid interpretation of backticks with Splatting
$stageParams = @{
    RedistDir         = $RedistDir
    RawSharedX64Dir   = $RawSharedX64Dir
    RawSharedX86Dir   = $RawSharedX86Dir
    RawSharedArm64Dir = $RawSharedArm64Dir
    CommonAssetsDir   = $CommonAssetsDir
    AssetsDir         = $AssetsDir
}

$commonScript = Join-Path (Split-Path -Parent $PSScriptRoot) "common\stage_windows_redist.ps1"
if (-not (Test-Path $commonScript)) {
    throw "FATAL: Shared helper script not found at: $commonScript"
}
& $commonScript @stageParams

if ($LASTEXITCODE -ne 0 -or -not $?) {
    # If LASTEXITCODE is 0 but it still failed (PowerShell error), force exit code 1
    $exitCode = if ($LASTEXITCODE -ne 0) { $LASTEXITCODE } else { 1 }
    exit $exitCode
}
