call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x86
mkdir win32-i386-hybridcrt
cd win32-i386-hybridcrt
set list=3.6.1 3.5.5 3.4.4 3.3.6
SET CL=/D_WIN32_WINNT=0x0601 /D_WIN32_IE=0x0900 %CL%
SET LINK=/SUBSYSTEM:CONSOLE,6.01 %LINK%
for %%a in (%list%) do (
  curl -sLo openssl-%%a.tar.gz https://github.com/openssl/openssl/archive/refs/tags/openssl-%%a.tar.gz
  tar zxf openssl-%%a.tar.gz
  cd openssl-openssl-%%a
  perl Configure VC-WIN32-HYBRIDCRT
  nmake
  "%ProgramFiles%\7-Zip\7z" a openssl-%%a-win32-i386.zip *.dll
  "%ProgramFiles%\7-Zip\7z" a openssl-%%a-win32-i386.zip LICENSE.txt
  cd apps
  "%ProgramFiles%\7-Zip\7z" a ../openssl-%%a-win32-i386.zip openssl.exe
  cd ..
  "%ProgramFiles%\7-Zip\7z" a openssl-%%a-win32-i386.zip providers/*.dll
  "%ProgramFiles%\7-Zip\7z" a openssl-%%a-win32-i386.zip engines/*.dll
  copy *.zip ..
  del *.zip
  cd ..
  echo "%%a complete"
)