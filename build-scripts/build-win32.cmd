call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x86
mkdir win32-hybrid
cd win32-hybrid
set list="3.6.0" "3.5.4" "3.4.3" "3.3.5" "3.2.6" "3.0.18" 
SET CL=/D_WIN32_WINNT=0x0601 /D_WIN32_IE=0x0900 %CL%
SET LINK=/SUBSYSTEM:CONSOLE,6.01 %LINK%
(for %%a in (%list%) do (
  curl -sLo openssl-%%a.tar.gz https://github.com/openssl/openssl/archive/refs/tags/openssl-%%a.tar.gz
  tar zxf openssl-%%a.tar.gz
  cd openssl-openssl-%%a
  perl Configure VC-WIN32-HYBRIDCRT
  nmake
  zip openssl-%%a-win32.zip *.dll
  zip openssl-%%a-win32.zip LICENSE.txt
  cd apps
  zip ../openssl-%%a-win32.zip openssl.exe
  cd ..
  zip openssl-%%a-win32.zip providers/*.dll
  zip openssl-%%a-win32.zip engines/*.dll
  copy *.zip ..
  del *.zip
  cd ..
  echo "%%a complete"
))