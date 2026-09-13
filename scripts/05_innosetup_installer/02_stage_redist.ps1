<#
.SYNOPSIS
    Job: 05_innosetup_installer | Stage Multi-Arch Redistributables
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceDir
)

$ErrorActionPreference = 'Stop'

$stageParams = @{
    RedistDir         = (Join-Path $WorkspaceDir "redist")
    AssetsDir         = (Join-Path $WorkspaceDir "assets")
    RawSharedX64Dir   = (Join-Path $WorkspaceDir "raw-shared-x64")
    RawSharedX86Dir   = (Join-Path $WorkspaceDir "raw-shared-x86")
    RawSharedArm64Dir = (Join-Path $WorkspaceDir "raw-shared-arm64")
    CommonAssetsDir   = (Join-Path $WorkspaceDir "common-assets")
}

$commonScript = Join-Path $WorkspaceDir "scripts\common\stage_windows_redist.ps1"
if (-not (Test-Path $commonScript)) {
    throw "FATAL: Shared helper script not found at: '$commonScript'"
}

& $commonScript @stageParams