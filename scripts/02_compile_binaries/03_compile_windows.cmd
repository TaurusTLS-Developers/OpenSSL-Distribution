@echo off
rem ===========================================================================
rem scripts/2_compile-binaries_5_compile_windows.cmd
rem Job: 2_compile-binaries | Step: 5 (Compile and Stage Windows Binaries)
rem Compiles OpenSSL with MSVC toolchain on Windows and stages binary layout.
rem ===========================================================================

setlocal enabledelayedexpansion

set "VCVARS=%~1"
set "TARGET_BASE=%~2"
set "LINKAGE=%~3"
set "SRC_DIR=%~4"
set "TEMP_DIR=%~5"
set "STAGED_DIR=%~6"

if "%VCVARS%"=="" set "VCVARS=amd64"
if "%TARGET_BASE%"=="" set "TARGET_BASE=VC-WIN64A"
if "%LINKAGE%"=="" set "LINKAGE=shared"
if "%SRC_DIR%"=="" set "SRC_DIR=%CD%\openssl-src"
if "%TEMP_DIR%"=="" set "TEMP_DIR=%CD%\temp_install"
if "%STAGED_DIR%"=="" set "STAGED_DIR=%CD%\raw_artifact\dist"

echo [COMPILE-WIN] Compiling Windows OpenSSL Binaries
echo   VCVARS      : %VCVARS%
echo   Target Base : %TARGET_BASE%
echo   Linkage     : %LINKAGE%
echo   Source Dir  : %SRC_DIR%
echo   Temp Dir    : %TEMP_DIR%
echo   Staged Dir  : %STAGED_DIR%

for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set "VS_PATH=%%i"

if "%VS_PATH%"=="" (
    echo [COMPILE-WIN] ERROR: Visual Studio installation path could not be found via vswhere.
    exit /b 1
)

echo [COMPILE-WIN] Calling vcvarsall.bat %VCVARS%...
call "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat" %VCVARS%
if errorlevel 1 (
    echo [COMPILE-WIN] ERROR: vcvarsall.bat failed.
    exit /b %errorlevel%
)

if not exist "%STAGED_DIR%\lib\static" mkdir "%STAGED_DIR%\lib\static"
if not exist "%STAGED_DIR%\lib\import" mkdir "%STAGED_DIR%\lib\import"
if not exist "%STAGED_DIR%\engines" mkdir "%STAGED_DIR%\engines"
if not exist "%STAGED_DIR%\providers" mkdir "%STAGED_DIR%\providers"

if /i "%LINKAGE%"=="shared" (
    set "TARGET_NAME=%TARGET_BASE%-SHARED"
) else (
    set "TARGET_NAME=%TARGET_BASE%-STATIC"
)

echo [COMPILE-WIN] Entering source directory: %SRC_DIR%
cd /d "%SRC_DIR%"
if errorlevel 1 (
    echo [COMPILE-WIN] ERROR: Could not change directory to %SRC_DIR%
    exit /b 1
)

echo [COMPILE-WIN] Running perl Configure %TARGET_NAME% --prefix="%TEMP_DIR%"
perl Configure %TARGET_NAME% --prefix="%TEMP_DIR%"
if errorlevel 1 (
    echo [COMPILE-WIN] ERROR: Configure failed.
    exit /b %errorlevel%
)

echo [COMPILE] Building in parallel with jom (%NUMBER_OF_PROCESSORS% cores)...
jom -j "%NUMBER_OF_PROCESSORS%"
if errorlevel 1 (
    echo FATAL: jom parallel compilation failed!
    exit /b %errorlevel%
)

:: Ensure dummy PDB exists to prevent older OpenSSL 3.0 copy.pl crash on static builds
if not exist ossl_static.pdb (type nul > ossl_static.pdb >nul 2>&1)

echo [COMPILE] Installing software via nmake install_sw...
nmake install_sw
if errorlevel 1 (
    echo FATAL: nmake install_sw failed!
    exit /b %errorlevel%
)

echo [COMPILE-WIN] Staging artifacts into %STAGED_DIR%...
if /i "%LINKAGE%"=="shared" (
    if exist "%TEMP_DIR%\bin\openssl.exe" copy /y "%TEMP_DIR%\bin\openssl.exe" "%STAGED_DIR%\"
    if exist "%TEMP_DIR%\bin\*.dll" copy /y "%TEMP_DIR%\bin\*.dll" "%STAGED_DIR%\"
    if exist "%TEMP_DIR%\lib\*.lib" copy /y "%TEMP_DIR%\lib\*.lib" "%STAGED_DIR%\lib\import\"
    if exist "%TEMP_DIR%\lib\engines-3\*.dll" copy /y "%TEMP_DIR%\lib\engines-3\*.dll" "%STAGED_DIR%\engines\"
    if exist "%TEMP_DIR%\lib\engines-4\*.dll" copy /y "%TEMP_DIR%\lib\engines-4\*.dll" "%STAGED_DIR%\engines\"
    if exist "%TEMP_DIR%\lib\ossl-modules\*.dll" copy /y "%TEMP_DIR%\lib\ossl-modules\*.dll" "%STAGED_DIR%\providers\"
) else (
    if exist "%TEMP_DIR%\lib\*.lib" copy /y "%TEMP_DIR%\lib\*.lib" "%STAGED_DIR%\lib\static\"
)

echo [COMPILE-WIN] ✅ Windows OpenSSL binaries successfully compiled and staged.
exit /b 0
