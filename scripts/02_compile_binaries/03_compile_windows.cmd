@echo off
setlocal EnableExtensions

set "VCVARS_ARG=%~1"
set "TARGET_BASE=%~2"
set "LINKAGE=%~3"
set "SRC_DIR=%~4"
set "INSTALL_TEMP=%~5"
set "STAGED_DIST=%~6"

if not defined GITHUB_WORKSPACE set "GITHUB_WORKSPACE=%CD%"
if not defined SRC_DIR          set "SRC_DIR=%GITHUB_WORKSPACE%\openssl-src"
if not defined INSTALL_TEMP     set "INSTALL_TEMP=%GITHUB_WORKSPACE%\temp_install"
if not defined STAGED_DIST      set "STAGED_DIST=%GITHUB_WORKSPACE%\raw_artifact\dist"
if not defined VCVARS_ARG       set "VCVARS_ARG=amd64"
if not defined TARGET_BASE      set "TARGET_BASE=VC-WIN64A"
if not defined LINKAGE          set "LINKAGE=shared"

echo ================================================================
echo  [COMPILE-WIN] VCVARS:       %VCVARS_ARG%
echo  [COMPILE-WIN] Target Base:  %TARGET_BASE%
echo  [COMPILE-WIN] Linkage:      %LINKAGE%
echo  [COMPILE-WIN] Source:       %SRC_DIR%
echo  [COMPILE-WIN] Install Temp: %INSTALL_TEMP%
echo  [COMPILE-WIN] Staging Dist: %STAGED_DIST%
echo ================================================================

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

:: 3. Prepare Staging Directories
if not exist "%STAGED_DIST%"              mkdir "%STAGED_DIST%"
if not exist "%STAGED_DIST%\lib\import"   mkdir "%STAGED_DIST%\lib\import"
if not exist "%STAGED_DIST%\lib\static"   mkdir "%STAGED_DIST%\lib\static"
if not exist "%STAGED_DIST%\engines"      mkdir "%STAGED_DIST%\engines"
if not exist "%STAGED_DIST%\providers"    mkdir "%STAGED_DIST%\providers"

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
echo [COMPILE-WIN] Running: perl Configure %TARGET_NAME% --prefix="%INSTALL_TEMP%"
perl Configure %TARGET_NAME% --prefix="%INSTALL_TEMP%"
if errorlevel 1 (
    echo FATAL: OpenSSL Configure failed for target '%TARGET_NAME%'!
    exit /b 1
)

:: Create dummy PDB so OpenSSL copy.pl succeeds during static install_sw
if not exist ossl_static.pdb echo dummy > ossl_static.pdb

:: 7. Build and Install via jom + nmake
echo [COMPILE-WIN] Building in parallel with jom (%NUMBER_OF_PROCESSORS% cores)...
jom -j "%NUMBER_OF_PROCESSORS%"
if errorlevel 1 (
    echo FATAL: jom parallel compilation failed!
    exit /b 1
)

if not exist ossl_static.pdb echo dummy > ossl_static.pdb

echo [COMPILE-WIN] Installing software via nmake install_sw...
nmake install_sw
if errorlevel 1 (
    echo FATAL: nmake install_sw failed!
    exit /b 1
)

:: 8. Stage Artifacts According to Linkage
echo [COMPILE-WIN] Staging compiled artifacts into '%STAGED_DIST%'...
if /i "%LINKAGE%"=="shared" (
    if exist "%INSTALL_TEMP%\bin\openssl.exe" (
        copy /Y "%INSTALL_TEMP%\bin\openssl.exe" "%STAGED_DIST%\"
    )
    copy /Y "%INSTALL_TEMP%\bin\*.dll" "%STAGED_DIST%\"
    copy /Y "%INSTALL_TEMP%\lib\*.lib" "%STAGED_DIST%\lib\import\"
    if exist "%INSTALL_TEMP%\lib\engines-3" copy /Y "%INSTALL_TEMP%\lib\engines-3\*.dll" "%STAGED_DIST%\engines\"
    if exist "%INSTALL_TEMP%\lib\engines-4" copy /Y "%INSTALL_TEMP%\lib\engines-4\*.dll" "%STAGED_DIST%\engines\"
    if exist "%INSTALL_TEMP%\lib\ossl-modules" copy /Y "%INSTALL_TEMP%\lib\ossl-modules\*.dll" "%STAGED_DIST%\providers\"
) else (
    copy /Y "%INSTALL_TEMP%\lib\*.lib" "%STAGED_DIST%\lib\static\"
)

:: 9. Strict Assertion: Ensure files were actually staged
dir /b /s "%STAGED_DIST%\*.lib" "%STAGED_DIST%\*.dll" "%STAGED_DIST%\*.exe" >nul 2>&1
if errorlevel 1 (
    echo FATAL: No binary or library files were staged into '%STAGED_DIST%'!
    exit /b 1
)

echo [COMPILE-WIN] Staging completed successfully for %TARGET_NAME%.
exit /b 0
