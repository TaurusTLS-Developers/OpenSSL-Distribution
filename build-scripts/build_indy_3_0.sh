#!/bin/bash
# This script requires nasm, and the MSYS2 version of Perl in addition to the standard
# toolchain.  You can install these using pacman.
#
  case "${MSYSTEM}" in
    MINGW32)
    _mingw=mingw
    _win=win32
    _subdir=mingw32
    _arch=i386
      ;;
    CLANG32)
    _mingw=mingw
    _win=win32
    _subdir=mingw32 
    _arch=i386
      ;;
    MINGW64)
    _mingw=mingw64
    _win=win64
    _subdir=mingw64
    _arch=x86_64
      ;;
   CLANG64)
   _mingw=mingw64
   _win=win64
   _subdir=mingw64
   _arch=x86_64
      ;;	
   CLANGARM64)
   _mingw=mingwarm64
   _win=win64
   _subdir=mingw64-arm
   _arch=arm64
    ;;
  esac

versions=("3.0.19")
mkdir ${_subdir}
cd ${_subdir}
for ver in "${versions[@]}"; do
  if [ ! -e "openssl-${ver}.tar.gz" ]; then
    wget https://github.com/openssl/openssl/archive/refs/tags/openssl-${ver}.tar.gz	
  fi
  
  rm -rf openssl-${ver} 
  

# now do shared
  tar zxf "openssl-${ver}.tar.gz"
  if [ -d openssl-${ver} ]; then 
    cd openssl-${ver}
  else
    cd openssl-openssl-${ver}
  fi
  /usr/bin/perl Configure ${_mingw} shared
  make
  zip "openssl-${ver}-${_win}-${_arch}.zip" *.dll
  zip "openssl-${ver}-${_win}-${_arch}.zip" LICENSE.txt
  cd apps
  zip ../"openssl-${ver}-${_win}-${_arch}.zip" openssl.exe
  cd ..
  zip "openssl-${ver}-${_win}-${_arch}.zip" providers/*.dll
  zip "openssl-${ver}-${_win}-${_arch}.zip" engines/*.dll
  mv "openssl-${ver}-${_win}-${_arch}.zip" ..
  cd ..
done
