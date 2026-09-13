<#
.SYNOPSIS
    Fuses native ARM64 and ARM64EC slices into true ARM64X binaries and dynamic modules.
.DESCRIPTION
    Uses $env:GITHUB_WORKSPACE (or current directory if running locally) automatically.
#>
[CmdletBinding()]
param(
    # Optional override for manual local testing; defaults to environment variable or PWD
    [string]$WorkspaceDir = ($env:GITHUB_WORKSPACE ?? $PWD.Path)
)

$ErrorActionPreference = 'Stop'

# Resolve workspace and target distribution directories
$wsDir      = $WorkspaceDir
$DistSharedDir = Join-Path $wsDir "raw_shared\dist"
$DistStaticDir = Join-Path $wsDir "raw_static\dist"
$distShared    = $DistSharedDir
$distStatic    = $DistStaticDir
$slicesDir     = Join-Path $wsDir "slices"

# Locate MSVC Tools
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath  = & $vswhere -latest -property installationPath
if ([string]::IsNullOrWhiteSpace($vsPath) -or -not (Test-Path $vsPath)) { 
    throw "FATAL: Visual Studio installation path could not be resolved!" 
}

$vcVars  = "$vsPath\VC\Auxiliary\Build\vcvarsall.bat"
$dumpbin = Get-ChildItem "$vsPath\VC\Tools\MSVC" -Recurse -Filter "dumpbin.exe" |
  Where-Object { $_.FullName -match 'Hostx64\\x64' } | Select-Object -ExpandProperty FullName -First 1
if ([string]::IsNullOrWhiteSpace($dumpbin) -or -not (Test-Path $dumpbin)) { 
    throw "FATAL: Hostx64 dumpbin.exe not found!" 
}

# Initialize output directory structure
New-Item -ItemType Directory -Force -Path `
  "$distStatic\lib\static\arm64", "$distStatic\lib\static\arm64ec", `
  "$distShared\lib\import\arm64", "$distShared\lib\import\arm64ec", `
  "$distShared\engines", "$distShared\providers" | Out-Null

Write-Host "=== Inspecting Slices in: $slicesDir ==="
if (-not (Test-Path $slicesDir)) {
    throw "FATAL: Slices directory '$slicesDir' does not exist! Artifact download step failed or path is wrong."
}
Get-ChildItem $slicesDir | ForEach-Object { Write-Host "  Found: $($_.Name)" }

# Resolve Slice Directories (Explicitly excluding *arm64ec* to prevent accidental collisions)
$arm64Shared   = Get-ChildItem $slicesDir -Directory | Where-Object { 
    ($_.Name -like "*native-arm64*shared*" -or $_.Name -like "*arm64*shared*") -and $_.Name -notlike "*arm64ec*" 
} | Select-Object -ExpandProperty FullName -First 1

$arm64Static   = Get-ChildItem $slicesDir -Directory | Where-Object { 
    ($_.Name -like "*native-arm64*static*" -or $_.Name -like "*arm64*static*") -and $_.Name -notlike "*arm64ec*" 
} | Select-Object -ExpandProperty FullName -First 1

$arm64ecShared = Get-ChildItem $slicesDir -Directory | Where-Object { 
    $_.Name -like "*arm64ec*shared*" 
} | Select-Object -ExpandProperty FullName -First 1

$arm64ecStatic = Get-ChildItem $slicesDir -Directory | Where-Object { 
    $_.Name -like "*arm64ec*static*" 
} | Select-Object -ExpandProperty FullName -First 1

Write-Host "`n=== Resolved Slices ==="
Write-Host "  arm64Shared:   $arm64Shared"
Write-Host "  arm64Static:   $arm64Static"
Write-Host "  arm64ecShared: $arm64ecShared"
Write-Host "  arm64ecStatic: $arm64ecStatic"

# Strict assertions: Fail immediately with clear error if any slice is missing
if (-not $arm64Shared)   { throw "FATAL: Could not find Native ARM64 Shared slice in $slicesDir!" }
if (-not $arm64Static)   { throw "FATAL: Could not find Native ARM64 Static slice in $slicesDir!" }
if (-not $arm64ecShared) { throw "FATAL: Could not find ARM64EC Shared slice in $slicesDir!" }
if (-not $arm64ecStatic) { throw "FATAL: Could not find ARM64EC Static slice in $slicesDir!" }

# Verify required input static libraries exist for both crypto and ssl before calling lib.exe
$arm64StaticCrypto   = Join-Path $arm64Static "lib\static\libcrypto.lib"
$arm64ecStaticCrypto = Join-Path $arm64ecStatic "lib\static\libcrypto.lib"
$arm64StaticSsl      = Join-Path $arm64Static "lib\static\libssl.lib"
$arm64ecStaticSsl    = Join-Path $arm64ecStatic "lib\static\libssl.lib"

if (-not (Test-Path $arm64StaticCrypto))   { throw "FATAL: Native ARM64 static libcrypto not found: $arm64StaticCrypto" }
if (-not (Test-Path $arm64ecStaticCrypto)) { throw "FATAL: ARM64EC static libcrypto not found: $arm64ecStaticCrypto" }
if (-not (Test-Path $arm64StaticSsl))      { throw "FATAL: Native ARM64 static libssl not found: $arm64StaticSsl" }
if (-not (Test-Path $arm64ecStaticSsl))    { throw "FATAL: ARM64EC static libssl not found: $arm64ecStaticSsl" }

Write-Host "✅ All required static input archives verified."

# 1. MERGE STATIC LIBRARIES (lib.exe /MACHINE:ARM64X)
Write-Host "`n=== 1. Merging Static Libraries (lib.exe /MACHINE:ARM64X) ==="
cmd.exe /c "call `"$vcVars`" amd64_arm64 && lib.exe /NOLOGO /MACHINE:ARM64X /OUT:`"$DistStaticDir\lib\static\libcrypto.lib`" `"$arm64Static\lib\static\libcrypto.lib`" `"$arm64ecStatic\lib\static\libcrypto.lib`""
if ($LASTEXITCODE -ne 0) { throw "FATAL: Static library libcrypto merge failed with exit code $LASTEXITCODE" }

cmd.exe /c "call `"$vcVars`" amd64_arm64 && lib.exe /NOLOGO /MACHINE:ARM64X /OUT:`"$DistStaticDir\lib\static\libssl.lib`" `"$arm64Static\lib\static\libssl.lib`" `"$arm64ecStatic\lib\static\libssl.lib`""
if ($LASTEXITCODE -ne 0) { throw "FATAL: Static library libssl merge failed with exit code $LASTEXITCODE" }

Copy-Item "$arm64Static\lib\static\*.lib" "$DistStaticDir\lib\static\arm64\" -Force
Copy-Item "$arm64ecStatic\lib\static\*.lib" "$DistStaticDir\lib\static\arm64ec\" -Force

# 2. LINK TRUE ARM64X CORE DLLs (libcrypto & libssl)
Write-Host "`n=== 2. Linking True ARM64X Core Libraries ==="
$cryptoDef = Get-ChildItem "$arm64ecShared\def" -Filter "*crypto*.def" | Select-Object -ExpandProperty FullName -First 1
$sslDef    = Get-ChildItem "$arm64ecShared\def" -Filter "*ssl*.def"    | Select-Object -ExpandProperty FullName -First 1

if (-not $cryptoDef) { throw "FATAL: libcrypto .def file not found in $arm64ecShared\def!" }
if (-not $sslDef)    { throw "FATAL: libssl .def file not found in $arm64ecShared\def!" }

# Link libcrypto-3-arm64.dll (ARM64X)
cmd.exe /c "call `"$vcVars`" amd64_arm64 && link.exe /NOLOGO /DLL /MACHINE:ARM64X /OUT:`"$DistSharedDir\libcrypto-3-arm64.dll`" /IMPLIB:`"$DistSharedDir\lib\import\libcrypto.lib`" /DEF:`"$cryptoDef`" /DEFARM64NATIVE:`"$cryptoDef`" `"$arm64Static\lib\static\libcrypto.lib`" `"$arm64ecStatic\lib\static\libcrypto.lib`" ws2_32.lib gdi32.lib advapi32.lib crypt32.lib user32.lib /NODEFAULTLIB:libucrt.lib /DEFAULTLIB:ucrt.lib"
if ($LASTEXITCODE -ne 0) { throw "FATAL: Core ARM64X libcrypto DLL linking failed with exit code $LASTEXITCODE" }

# Link libssl-3-arm64.dll (ARM64X)
cmd.exe /c "call `"$vcVars`" amd64_arm64 && link.exe /NOLOGO /DLL /MACHINE:ARM64X /OUT:`"$DistSharedDir\libssl-3-arm64.dll`" /IMPLIB:`"$DistSharedDir\lib\import\libssl.lib`" /DEF:`"$sslDef`" /DEFARM64NATIVE:`"$sslDef`" `"$arm64Static\lib\static\libssl.lib`" `"$arm64ecStatic\lib\static\libssl.lib`" `"$arm64Static\lib\static\libcrypto.lib`" `"$arm64ecStatic\lib\static\libcrypto.lib`" `"$DistSharedDir\lib\import\libcrypto.lib`" ws2_32.lib gdi32.lib advapi32.lib crypt32.lib user32.lib /NODEFAULTLIB:libucrt.lib /DEFAULTLIB:ucrt.lib"
if ($LASTEXITCODE -ne 0) { throw "FATAL: Core ARM64X libssl DLL linking failed with exit code $LASTEXITCODE" }

Copy-Item "$arm64Shared\lib\import\*.lib" "$DistSharedDir\lib\import\arm64\" -Force
Copy-Item "$arm64ecShared\lib\import\*.lib" "$DistSharedDir\lib\import\arm64ec\" -Force

# 3. LINK TRUE ARM64X PROVIDERS (legacy.dll)
Write-Host "`n=== 3. Linking True ARM64X Providers ==="
if (Test-Path "$arm64ecShared\providers\legacy.dll") {
    Write-Host "  -> Fusing ARM64X provider: providers\legacy.dll"

    $mergedLegacyLib = "$wsDir\arm64x_liblegacy.lib"
    $mergedCommonLib = "$wsDir\arm64x_libcommon.lib"

    cmd.exe /c "call `"$vcVars`" amd64_arm64 && lib.exe /NOLOGO /MACHINE:ARM64X /OUT:`"$mergedLegacyLib`" `"$arm64Shared\providers\liblegacy.lib`" `"$arm64ecShared\providers\liblegacy.lib`""
    if ($LASTEXITCODE -ne 0) { throw "FATAL: Failed to merge liblegacy.lib into ARM64X!" }

    cmd.exe /c "call `"$vcVars`" amd64_arm64 && lib.exe /NOLOGO /MACHINE:ARM64X /OUT:`"$mergedCommonLib`" `"$arm64Shared\providers\libcommon.lib`" `"$arm64ecShared\providers\libcommon.lib`""
    if ($LASTEXITCODE -ne 0) { throw "FATAL: Failed to merge libcommon.lib into ARM64X!" }

    $exportsDump = & $dumpbin /exports "$arm64ecShared\providers\legacy.dll" | Out-String
    $exportLines = ($exportsDump -split "`r?`n") | Where-Object { $_ -match '^\s+\d+\s+[0-9A-F]+\s+[0-9A-F]+\s+(\S+)$' } | ForEach-Object { $matches[1] }
    if ($exportLines.Count -eq 0) { $exportLines = @("OSSL_provider_init") }

    $legacyDef = "$wsDir\def_legacy.def"
    $defContent = "LIBRARY legacy`r`nEXPORTS`r`n" + ($exportLines -join "`r`n")
    [IO.File]::WriteAllText($legacyDef, $defContent)

    $legacyObjArm64   = Get-ChildItem "$arm64Shared\providers" -Filter "*legacy*.obj" | Select-Object -ExpandProperty FullName -First 1
    $legacyObjArm64ec = Get-ChildItem "$arm64ecShared\providers" -Filter "*legacy*.obj" | Select-Object -ExpandProperty FullName -First 1

    if (-not $legacyObjArm64 -or -not $legacyObjArm64ec) {
        throw "FATAL: legacyprov entry point object not found in slice artifacts!"
    }

    $legacyRsp = "$wsDir\link_legacy.rsp"
    $rspLines = @(
        "/NOLOGO",
        "/DLL",
        "/MACHINE:ARM64X",
        "/OUT:`"$DistSharedDir\providers\legacy.dll`"",
        "/DEF:`"$legacyDef`"",
        "/DEFARM64NATIVE:`"$legacyDef`"",
        "`"$legacyObjArm64`"",
        "`"$legacyObjArm64ec`"",
        "`"$mergedLegacyLib`"",
        "`"$mergedCommonLib`"",
        "`"$DistSharedDir\lib\import\libcrypto.lib`"",
        "ws2_32.lib", "gdi32.lib", "advapi32.lib", "crypt32.lib", "user32.lib",
        "/NODEFAULTLIB:libucrt.lib", "/DEFAULTLIB:ucrt.lib"
    )
    [IO.File]::WriteAllLines($legacyRsp, $rspLines)

    cmd.exe /c "call `"$vcVars`" amd64_arm64 && link.exe @`"$legacyRsp`""
    if ($LASTEXITCODE -ne 0) { throw "FATAL: Failed to link true ARM64X providers\legacy.dll!" }
    Write-Host "     [+] Successfully linked TRUE ARM64X providers\legacy.dll"
}

# 4. LINK TRUE ARM64X ENGINES
Write-Host "`n=== 4. Linking True ARM64X Engines ==="
if (Test-Path "$arm64ecShared\engines") {
    $engineDlls = Get-ChildItem "$arm64ecShared\engines" -Filter "*.dll"
    foreach ($dll in $engineDlls) {
        $engName = $dll.BaseName
        Write-Host "  -> Fusing ARM64X engine: engines\$($dll.Name)"

        $exportsDump = & $dumpbin /exports $dll.FullName | Out-String
        $exportLines = ($exportsDump -split "`r?`n") | Where-Object { $_ -match '^\s+\d+\s+[0-9A-F]+\s+[0-9A-F]+\s+(\S+)$' } | ForEach-Object { $matches[1] }
        if ($exportLines.Count -eq 0) { $exportLines = @("bind_engine", "v_check") }

        $engDef = "$wsDir\def_$engName.def"
        $defContent = "LIBRARY $engName`r`nEXPORTS`r`n" + ($exportLines -join "`r`n")
        [IO.File]::WriteAllText($engDef, $defContent)

        $engObjsArm64   = @(Get-ChildItem "$arm64Shared\engines" -Filter "*$engName*.obj" | Select-Object -ExpandProperty FullName)
        $engObjsArm64ec = @(Get-ChildItem "$arm64ecShared\engines" -Filter "*$engName*.obj" | Select-Object -ExpandProperty FullName)

        if ($engObjsArm64.Count -eq 0 -or $engObjsArm64ec.Count -eq 0) {
            throw "FATAL: Object files for engine $engName not found in slice artifacts!"
        }

        $allEngObjs = $engObjsArm64 + $engObjsArm64ec

        $engRsp = "$wsDir\link_$engName.rsp"
        $rspLines = @(
            "/NOLOGO",
            "/DLL",
            "/MACHINE:ARM64X",
            "/OUT:`"$DistSharedDir\engines\$($dll.Name)`"",
            "/DEF:`"$engDef`"",
            "/DEFARM64NATIVE:`"$engDef`"",
            "`"$DistSharedDir\lib\import\libcrypto.lib`"",
            "ws2_32.lib", "gdi32.lib", "advapi32.lib", "crypt32.lib", "user32.lib",
            "/NODEFAULTLIB:libucrt.lib", "/DEFAULTLIB:ucrt.lib"
        ) + ($allEngObjs | ForEach-Object { "`"$_`"" })

        [IO.File]::WriteAllLines($engRsp, $rspLines)

        cmd.exe /c "call `"$vcVars`" amd64_arm64 && link.exe @`"$engRsp`""
        if ($LASTEXITCODE -ne 0) { throw "FATAL: Failed to link true ARM64X engines\$($dll.Name)!" }
        Write-Host "     [+] Successfully linked TRUE ARM64X engines\$($dll.Name)"
    }
}

# 5. STAGE PURE NATIVE ARM64 openssl.exe
Write-Host "`n=== 5. Staging Native ARM64 openssl.exe ==="
if (-not (Test-Path "$arm64Shared\openssl.exe")) {
    throw "FATAL: Native ARM64 openssl.exe not found in $arm64Shared!"
}
Copy-Item "$arm64Shared\openssl.exe" "$DistSharedDir\openssl.exe" -Force

# 6. STRICT CLEANUP
Write-Host "`n=== 6. Cleaning Up Leftover Build Artifacts ==="
Get-ChildItem "$DistSharedDir\engines", "$DistSharedDir\providers" -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -ne '.dll' } |
    ForEach-Object {
        Write-Host "  [-] Removing intermediate build file: $($_.FullName)"
        Remove-Item $_.FullName -Force
    }

Get-ChildItem "$DistSharedDir\lib\import" -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -ne '.lib' } |
    ForEach-Object {
        Write-Host "  [-] Removing intermediate import file: $($_.FullName)"
        Remove-Item $_.FullName -Force
    }

Write-Host "[FUSE-ARM64X] ✅ ARM64X Fusion completed successfully."
