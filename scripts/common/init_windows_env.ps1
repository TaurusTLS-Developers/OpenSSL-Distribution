<#
.SYNOPSIS
    Locates Visual Studio toolchain and returns or exports compiler/tool paths.
.DESCRIPTION
    Uses vswhere.exe to dynamically locate the latest Visual Studio installation,
    MSVC Hostx64 tools (dumpbin.exe, lib.exe, link.exe), and vcvarsall.bat.
.PARAMETER Arch
    Optional architecture to initialize in current process (e.g., amd64, x86, amd64_arm64).
#>
[CmdletBinding()]
param(
    [string]$Arch = ""
)

$ErrorActionPreference = 'Stop'

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Write-Error "vswhere.exe not found at '$vswhere'"
    exit 1
}

$vsPath = & $vswhere -latest -property installationPath
if (-not (Test-Path $vsPath)) {
    Write-Error "Visual Studio installation path could not be resolved via vswhere."
    exit 1
}

$vcVars = "$vsPath\VC\Auxiliary\Build\vcvarsall.bat"
if (-not (Test-Path $vcVars)) {
    Write-Error "vcvarsall.bat not found at '$vcVars'"
    exit 1
}

$dumpbin = Get-ChildItem "$vsPath\VC\Tools\MSVC" -Recurse -Filter "dumpbin.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'Hostx64\\x64' } | Select-Object -ExpandProperty FullName -First 1

if (-not $dumpbin -or -not (Test-Path $dumpbin)) {
    $dumpbinCmd = Get-Command dumpbin.exe -ErrorAction SilentlyContinue
    if ($dumpbinCmd) { $dumpbin = $dumpbinCmd.Source }
}

Write-Host "[INIT-ENV] Visual Studio Path : $vsPath"
Write-Host "[INIT-ENV] vcvarsall.bat      : $vcVars"
if ($dumpbin) { Write-Host "[INIT-ENV] dumpbin.exe         : $dumpbin" }

$result = [PSCustomObject]@{
    VSPath   = $vsPath
    VCVars   = $vcVars
    Dumpbin  = $dumpbin
}

return $result
