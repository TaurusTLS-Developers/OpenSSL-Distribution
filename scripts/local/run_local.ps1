<#
.SYNOPSIS
    Local GitHub Actions Runner Emulator for OpenSSL CI/CD.
.DESCRIPTION
    Sets up the execution environment, initializes .runner/ output files,
    and runs any script or job locally with the same environment variables as CI.
.EXAMPLE
    .\run-local.ps1 -Script "scripts/02_compile_binaries/01_validate_secrets.ps1"
    .\run-local.ps1 -Job "04_merge_arm64x"
    .\run-local.ps1 -Job "02_compile_binaries" -Arch "x64" -Linkage "shared"
#>
[CmdletBinding()]
param(
    [string]$Script,
    [string]$Job,
    [string]$Version = "3.4.0",
    [string]$Arch = "x64",
    [ValidateSet("shared", "static")]
    [string]$Linkage = "shared",
    [string]$Platform = "Windows",
    [switch]$AllowMissingSecrets
)

$ErrorActionPreference = 'Stop'
$ws = $PWD.Path

Write-Host "================================================================"
Write-Host " Initializing Local Runner Environment in: $ws"
Write-Host "================================================================"

# 1. Create .runner directory for state emulation
$runnerDir = Join-Path $ws ".runner"
New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null

$env:GITHUB_WORKSPACE   = $ws
$env:GITHUB_OUTPUT      = Join-Path $runnerDir "github_output.txt"
$env:GITHUB_ENV         = Join-Path $runnerDir "github_env.txt"

# Reset output files for this run
"" | Set-Content -Path $env:GITHUB_OUTPUT
"" | Set-Content -Path $env:GITHUB_ENV

# 2. Set Global Path Contract (Identical to CI)
$env:SCRIPTS_DIR        = Join-Path $ws "scripts"
$env:COMMON_SCRIPTS_DIR = Join-Path $ws "scripts\common"
$env:CONFIG_DIR         = Join-Path $ws "config"
$env:ASSETS_DIR         = Join-Path $ws "assets"
$env:REDIST_DIR         = Join-Path $ws "redist"
$env:INSTALLERS_DIR     = Join-Path $ws "installers"
$env:COMMON_ASSETS_DIR  = Join-Path $ws "common-assets"

# Add common scripts to PATH so scripts can call each other directly
$env:PATH = "$env:COMMON_SCRIPTS_DIR;$env:PATH"

# 3. Set Version and Target Metadata
$parts = $Version -split '\.'
$env:OPENSSL_VERSION     = $Version
$env:OPENSSL_MAJOR_MINOR = "$($parts[0]).$($parts[1])"
$env:TARGET_ARCH         = $Arch
$env:TARGET_LINKAGE      = $Linkage
$env:TARGET_PLATFORM     = $Platform

Write-Host "  [+] GITHUB_WORKSPACE   = $env:GITHUB_WORKSPACE"
Write-Host "  [+] COMMON_SCRIPTS_DIR = $env:COMMON_SCRIPTS_DIR"
Write-Host "  [+] OPENSSL_VERSION    = $env:OPENSSL_VERSION ($env:OPENSSL_MAJOR_MINOR)"
Write-Host "  [+] TARGET             = $env:TARGET_PLATFORM $env:TARGET_ARCH ($env:TARGET_LINKAGE)"

# 4. Execute single script if specified
if ($Script) {
    $targetScript = if ([System.IO.Path]::IsPathRooted($Script)) { $Script } else { Join-Path $ws $Script }
    if (-not (Test-Path $targetScript)) {
        throw "Script not found: $targetScript"
    }

    Write-Host "`n--- Executing: $Script ---"
    if ($targetScript.EndsWith(".ps1")) {
        & $targetScript
    } elseif ($targetScript.EndsWith(".cmd") -or $targetScript.EndsWith(".bat")) {
        cmd.exe /c $targetScript
    } elseif ($targetScript.EndsWith(".sh")) {
        bash $targetScript
    }
    exit $LASTEXITCODE
}

# 5. Execute Job if specified
if ($Job) {
    $jobDir = Join-Path $ws "scripts\$Job"
    if (-not (Test-Path $jobDir)) {
        throw "Job directory not found: $jobDir"
    }

    $scriptsToRun = Get-ChildItem $jobDir -File | Sort-Object Name
    Write-Host "`nFound $($scriptsToRun.Count) step(s) in $Job to execute:"
    
    foreach ($s in $scriptsToRun) {
        Write-Host "`n>>> Running Step: $($s.Name) <<<"
        if ($s.Extension -eq ".ps1") {
            & $s.FullName
        } elseif ($s.Extension -in ".cmd", ".bat") {
            cmd.exe /c $s.FullName
        } elseif ($s.Extension -eq ".sh") {
            bash $s.FullName
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Step $($s.Name) failed with exit code $LASTEXITCODE!"
        }
    }
    Write-Host "`n✅ Job $Job completed successfully!"
    exit 0
}

Write-Host "`nReady. Run with -Script <path> or -Job <job_name> to test locally."