@echo off
rem ===========================================================================
rem scripts/2b_compile-windows-arm64x-slices_4_compile_slice.cmd
rem Job: 2b_compile-windows-arm64x-slices | Step: 4 (Compile and Stage Slice Binaries)
rem Compiles native ARM64 or ARM64EC slice and stages DSO object files and .defs.
rem ===========================================================================

setlocal enabledelayedexpansion

set "VCVARS=%~1"
set "TARGET_BASE=%~2"
set "LINKAGE=%~3"
set "SRC_DIR=%~4"
set "TEMP_DIR=%~5"
set "STAGED_DIR=%~6"

if "%VCVARS%"=="" set "VCVARS=amd64_arm64"
if "%TARGET_BASE%"=="" set "TARGET_BASE=VC-WIN64-ARM"
if "%LINKAGE%"=="" set "LINKAGE=shared"
if "%SRC_DIR%"=="" set "SRC_DIR=%CD%\openssl-src"
if "%TEMP_DIR%"=="" set "TEMP_DIR=%CD%\temp_install"
if "%STAGED_DIR%"=="" set "STAGED_DIR=%CD%\slice_out"

echo [COMPILE-SLICE] Compiling ARM64X Slice Binaries
echo   VCVARS      : %VCVARS%
echo   Target Base : %TARGET_BASE%
echo   Linkage     : %LINKAGE%
echo   Source Dir  : %SRC_DIR%
echo   Temp Dir    : %TEMP_DIR%
echo   Staged Dir  : %STAGED_DIR%

for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set "VS_PATH=%%i"

if "%VS_PATH%"=="" (
    echo [COMPILE-SLICE] ERROR: Visual Studio installation path could not be resolved.
    exit /b 1
)

echo [COMPILE-SLICE] Calling vcvarsall.bat %VCVARS%...
call "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat" %VCVARS%
if errorlevel 1 (
    echo [COMPILE-SLICE] ERROR: vcvarsall.bat failed.
    exit /b %errorlevel%
)

if not exist "%STAGED_DIR%\lib\static" mkdir "%STAGED_DIR%\lib\static"
if not exist "%STAGED_DIR%\lib\import" mkdir "%STAGED_DIR%\lib\import"
if not exist "%STAGED_DIR%\engines" mkdir "%STAGED_DIR%\engines"
if not exist "%STAGED_DIR%\providers" mkdir "%STAGED_DIR%\providers"
if not exist "%STAGED_DIR%\def" mkdir "%STAGED_DIR%\def"

if /i "%LINKAGE%"=="shared" (
    set "TARGET_NAME=%TARGET_BASE%-SHARED"
) else (
    set "TARGET_NAME=%TARGET_BASE%-STATIC"
)

echo [COMPILE-SLICE] Entering source directory: %SRC_DIR%
cd /d "%SRC_DIR%"
if errorlevel 1 (
    echo [COMPILE-SLICE] ERROR: Failed to change directory to %SRC_DIR%
    exit /b 1
)

echo [COMPILE-SLICE] Configuring %TARGET_NAME%...
perl Configure %TARGET_NAME% --prefix="%TEMP_DIR%"
if errorlevel 1 (
    echo [COMPILE-SLICE] ERROR: Configure failed.
    exit /b %errorlevel%
)

echo [COMPILE-SLICE] Running nmake...
nmake
if errorlevel 1 (
    echo [COMPILE-SLICE] ERROR: nmake failed.
    exit /b %errorlevel%
)

echo [COMPILE-SLICE] Running nmake install_sw...
nmake install_sw
if errorlevel 1 (
    echo [COMPILE-SLICE] ERROR: nmake install_sw failed.
    exit /b %errorlevel%
)

echo [COMPILE-SLICE] Staging slice files into %STAGED_DIR%...
if /i "%LINKAGE%"=="shared" (
    if exist "%TEMP_DIR%\bin\openssl.exe" copy /y "%TEMP_DIR%\bin\openssl.exe" "%STAGED_DIR%\"
    if exist "%TEMP_DIR%\bin\*.dll" copy /y "%TEMP_DIR%\bin\*.dll" "%STAGED_DIR%\"
    if exist "%TEMP_DIR%\lib\*.lib" copy /y "%TEMP_DIR%\lib\*.lib" "%STAGED_DIR%\lib\import\"
    if exist "%TEMP_DIR%\lib\engines-3\*.dll" copy /y "%TEMP_DIR%\lib\engines-3\*.dll" "%STAGED_DIR%\engines\"
    if exist "%TEMP_DIR%\lib\engines-4\*.dll" copy /y "%TEMP_DIR%\lib\engines-4\*.dll" "%STAGED_DIR%\engines\"
    if exist "%TEMP_DIR%\lib\ossl-modules\*.dll" copy /y "%TEMP_DIR%\lib\ossl-modules\*.dll" "%STAGED_DIR%\providers\"

    if exist "*.def" copy /y "*.def" "%STAGED_DIR%\def\"
    if exist "util\*.def" copy /y "util\*.def" "%STAGED_DIR%\def\"
    if exist "providers\*.def" copy /y "providers\*.def" "%STAGED_DIR%\def\"
    if exist "engines\*.def" copy /y "engines\*.def" "%STAGED_DIR%\def\"

    if exist "providers\*.lib" copy /y "providers\*.lib" "%STAGED_DIR%\providers\"
    if exist "providers\*-dso-*.obj" copy /y "providers\*-dso-*.obj" "%STAGED_DIR%\providers\"
    if exist "providers\*.obj" copy /y "providers\*.obj" "%STAGED_DIR%\providers\"

    for /r . %%f in (*-dso-*.obj) do @copy /y "%%f" "%STAGED_DIR%\engines\" >nul 2>&1
    if exist "engines\*.obj" copy /y "engines\*.obj" "%STAGED_DIR%\engines\"
) else (
    if exist "%TEMP_DIR%\lib\*.lib" copy /y "%TEMP_DIR%\lib\*.lib" "%STAGED_DIR%\lib\static\"
)

echo [COMPILE-SLICE] ✅ Slice binaries successfully compiled and staged.
exit /b 0
