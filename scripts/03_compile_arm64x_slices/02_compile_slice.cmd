@echo off
setlocal EnableExtensions

:: =========================================================================
:: Script: 02_compile_slice.cmd
:: Job:    03_compile_arm64x_slices
:: Desc:   Compiles an individual ARM64 or ARM64EC slice and stages objects/libs
:: =========================================================================

set "VCVARS_ARG=%~1"
set "TARGET_BASE=%~2"
set "LINKAGE=%~3"
set "SRC_DIR=%~4"
set "INSTALL_TEMP=%~5"
set "STAGED_OUT=%~6"

:: Smart Defaults for Local Testing
if not defined GITHUB_WORKSPACE set "GITHUB_WORKSPACE=%CD%"
if not defined SRC_DIR          set "SRC_DIR=%GITHUB_WORKSPACE%\openssl-src"
if not defined INSTALL_TEMP     set "INSTALL_TEMP=%GITHUB_WORKSPACE%\temp_install"
if not defined STAGED_OUT       set "STAGED_OUT=%GITHUB_WORKSPACE%\slice_out"
if not defined VCVARS_ARG       set "VCVARS_ARG=amd64_arm64"
if not defined TARGET_BASE      set "TARGET_BASE=VC-WIN64-ARM"
if not defined LINKAGE          set "LINKAGE=shared"

echo [COMPILE-SLICE] VCVARS:       %VCVARS_ARG%
echo [COMPILE-SLICE] Target Base:  %TARGET_BASE%
echo [COMPILE-SLICE] Linkage:      %LINKAGE%
echo [COMPILE-SLICE] Source:       %SRC_DIR%
echo [COMPILE-SLICE] Staging:      %STAGED_OUT%

:: 1. Locate Visual Studio via vswhere.exe
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set "VS_PATH=%%i"
if not defined VS_PATH (
    echo FATAL: Microsoft Visual Studio installation was not found via vswhere.exe!
    exit /b 1
)

:: 2. Initialize MSVC Environment
call "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat" %VCVARS_ARG%
if errorlevel 1 (
    echo FATAL: vcvarsall.bat failed to initialize environment for '%VCVARS_ARG%'!
    exit /b 1
)

:: 3. Prepare Slice Staging Directories
if not exist "%STAGED_OUT%"                   mkdir "%STAGED_OUT%"
if not exist "%STAGED_OUT%\lib\import"        mkdir "%STAGED_OUT%\lib\import"
if not exist "%STAGED_OUT%\lib\static"        mkdir "%STAGED_OUT%\lib\static"
if not exist "%STAGED_OUT%\engines"           mkdir "%STAGED_OUT%\engines"
if not exist "%STAGED_OUT%\providers"         mkdir "%STAGED_OUT%\providers"
if not exist "%STAGED_OUT%\def"               mkdir "%STAGED_OUT%\def"

:: 4. Resolve Target Name
if /i "%LINKAGE%"=="shared" (
    set "TARGET_NAME=%TARGET_BASE%-SHARED"
) else (
    set "TARGET_NAME=%TARGET_BASE%-STATIC"
)

:: 5. Switch to OpenSSL Source Directory
cd /d "%SRC_DIR%"
if errorlevel 1 (
    echo FATAL: Failed to switch directory to '%SRC_DIR%'!
    exit /b 1
)

:: 6. Configure OpenSSL
echo [COMPILE-SLICE] Running: perl Configure %TARGET_NAME% --prefix="%INSTALL_TEMP%"
perl Configure %TARGET_NAME% --prefix="%INSTALL_TEMP%"
if errorlevel 1 (
    echo FATAL: OpenSSL Configure failed for slice '%TARGET_NAME%'!
    exit /b %errorlevel%
)

:: Neutralize obsolete PDB installation rule from generated makefile for /Z7 static builds
perl -i -pe "s/.*ossl_static\.pdb.*//g" makefile
if not exist ossl_static.pdb echo dummy > ossl_static.pdb

:: 7. Build and Install
echo [COMPILE-SLICE] Building in parallel with jom (%NUMBER_OF_PROCESSORS% cores)...
jom -j "%NUMBER_OF_PROCESSORS%"
if errorlevel 1 (
    echo FATAL: jom parallel compilation failed for slice '%TARGET_NAME%'!
    exit /b %errorlevel%
)

if not exist ossl_static.pdb echo dummy > ossl_static.pdb

echo [COMPILE-SLICE] Installing software via nmake install_sw...
nmake install_sw
if errorlevel 1 (
    echo FATAL: nmake install_sw failed for slice '%TARGET_NAME%'!
    exit /b %errorlevel%
)

:: 8. Stage Artifacts & Intermediate Build Files for ARM64X Fusion
echo [COMPILE-SLICE] Staging slice artifacts and intermediate objects...
if /i "%LINKAGE%"=="shared" (
    if exist "%INSTALL_TEMP%\bin\openssl.exe" copy /Y "%INSTALL_TEMP%\bin\openssl.exe" "%STAGED_OUT%\" >nul
    copy /Y "%INSTALL_TEMP%\bin\*.dll" "%STAGED_OUT%\" >nul
    copy /Y "%INSTALL_TEMP%\lib\*.lib" "%STAGED_OUT%\lib\import\" >nul
    if exist "%INSTALL_TEMP%\lib\engines-3" copy /Y "%INSTALL_TEMP%\lib\engines-3\*.dll" "%STAGED_OUT%\engines\" >nul
    if exist "%INSTALL_TEMP%\lib\engines-4" copy /Y "%INSTALL_TEMP%\lib\engines-4\*.dll" "%STAGED_OUT%\engines\" >nul
    if exist "%INSTALL_TEMP%\lib\ossl-modules" copy /Y "%INSTALL_TEMP%\lib\ossl-modules\*.dll" "%STAGED_OUT%\providers\" >nul

    :: Stage module definition (.def) files
    if exist "*.def" copy /Y "*.def" "%STAGED_OUT%\def\" >nul
    if exist "util\*.def" copy /Y "util\*.def" "%STAGED_OUT%\def\" >nul
    if exist "providers\*.def" copy /Y "providers\*.def" "%STAGED_OUT%\def\" >nul
    if exist "engines\*.def" copy /Y "engines\*.def" "%STAGED_OUT%\def\" >nul

    :: Stage OpenSSL provider helper libraries & objects (e.g. liblegacy.lib, libcommon.lib)
    if exist "providers\*.lib" copy /Y "providers\*.lib" "%STAGED_OUT%\providers\" >nul
    if exist "providers\*-dso-*.obj" copy /Y "providers\*-dso-*.obj" "%STAGED_OUT%\providers\" >nul
    if exist "providers\*.obj" copy /Y "providers\*.obj" "%STAGED_OUT%\providers\" >nul

    :: Stage engine DSO objects across the build tree (including crypto/pem/loader_attic-dso-pvkfmt.obj)
    for /r . %%f in (*-dso-*.obj) do @copy /Y "%%f" "%STAGED_OUT%\engines\" >nul 2>&1
    if exist "engines\*.obj" copy /Y "engines\*.obj" "%STAGED_OUT%\engines\" >nul
) else (
    copy /Y "%INSTALL_TEMP%\lib\*.lib" "%STAGED_OUT%\lib\static\" >nul
)

echo [COMPILE-SLICE] Slice staging completed successfully for %TARGET_NAME%.
exit /b 0
