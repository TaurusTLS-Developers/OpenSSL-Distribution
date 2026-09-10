<#
.SYNOPSIS
    Initializes standard clean directory tree for local builds.
.PARAMETER BaseDir
    Root directory for workspace (defaults to current directory).
#>
[CmdletBinding()]
param(
    [string]$BaseDir = $PWD.Path
)

$directories = @(
    "raw_artifact\dist",
    "common-assets\usr\local",
    "redist\x64",
    "redist\x86",
    "redist\arm64",
    "installers",
    "slices",
    "dist"
)

Write-Host "[INIT-WORKSPACE] Initializing standard workspace directories under '$BaseDir'..."
foreach ($dir in $directories) {
    $fullPath = Join-Path $BaseDir $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
        Write-Host "  [+] Created: $dir"
    }
}

Write-Host "[INIT-WORKSPACE] ✅ Workspace directories ready."
