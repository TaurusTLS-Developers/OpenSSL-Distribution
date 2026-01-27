call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" amd64_arm64
mkdir win64-arm
cd win64-arm
set list=3.6.1 3.5.5 3.4.4 3.3.6 3.0.19
SET CL=/D_WIN32_WINNT=0x0601 /D_WIN32_IE=0x0900 %CL%
SET LINK=/SUBSYSTEM:CONSOLE,6.01 %LINK%
for %%a in (%list%) do (
  curl -sLo openssl-%%a.tar.gz https://github.com/openssl/openssl/archive/refs/tags/openssl-%%a.tar.gz
  tar zxf openssl-%%a.tar.gz
  cd openssl-openssl-%%a
  perl Configure VC-WIN64-ARM 
  nmake
  "%ProgramFiles%\7-Zip\7z" a openssl-%%a-win64-arm64.zip *.dll
  "%ProgramFiles%\7-Zip\7z" a openssl-%%a-win64-arm64.zip LICENSE.txt
  cd apps
  "%ProgramFiles%\7-Zip\7z" a ../openssl-%%a-win64-arm64.zip openssl.exe
  cd ..
  "%ProgramFiles%\7-Zip\7z" a openssl-%%a-win64-arm64.zip providers/*.dll
  "%ProgramFiles%\7-Zip\7z" a openssl-%%a-win64-arm64.zip engines/*.dll
  copy *.zip ..
  del *.zip
  cd ..
  echo "%%a complete"
)