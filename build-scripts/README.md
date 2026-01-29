# Build Scripts

This folder contains various scripts to build OpenSSL binaries for various platforms

* `build_indy_3_0.sh` 
  
  Builds various 3.0 version of OpenSSL DLLs for Windows 32-bit and 64-bit using MSYS2/MINGW toolchain.  Use either MSYS2 MINGW64, or MSYS2 MINGW32 shortcuts.

  Can be modified to build older/newer 3.x versions of OpenSSL
* `build-win32-i386.cmd`

  Builds various Win32-i386 OpenSSL 3.x versions using Visual Studio Community Edition 2022, nasm, Strawberry Perl, and 7-Zip.
* `build-win64-arm64.cmd`

  Builds various Win64-arm64 OpenSSL 3.x versions using Visual Studio Community Edition 2022, nasm, Strawberry Perl, and 7-Zip.  
* `build-win64-x86_64.cmd`

  Builds various Win64-x86_64 OpenSSL 3.x versions using Visual Studio Community Edition 2022, nasm, Strawberry Perl, and 7-Zip.
* `build_old_1x_dist.sh` 
  
  Builds version 1.1.1w of OpenSSL DLLs for Windows 32-bit and 64-bit
* `build-openssl-android.sh` 
  
  A script for macOS that builds version 3.5.0 of OpenSSL static libraries for Android 32-bit and 64-bit ARM CPUs
  
  Can be modified to build older/newer 3.x versions of OpenSSL, and possibly be modified to build on other platforms (e.g Windows)

For building OpenSSL libraries for iOS and macOS, please follow these instructions (NOTE: Needs to be run on a Mac):

1. Clone https://github.com/passepartoutvpn/openssl-apple
2. Edit the build-libssl.sh file in the root of the repo to change the iOS minimum SDK value to 11.0, i.e.:
   
   ```
   IOS_MIN_SDK_VERSION="11.0"
   ```
   This is to make sure it's compatible with the default linker option in Delphi (Project Options > Building > Delphi Compiler > Linking, Minimum iOS version supported)
3. Open a terminal window and change directory to the cloned repo
4. Issue this command:
   
   ```
   chmod +x build-libssl.sh
   ```
5. Execute the script for the version of OpenSSL required, e.g.:
   
   ```
   ./build-libssl.sh --version=3.5.0 --targets="ios64-cross-arm64 macos64-x86_64 macos64-arm64" --disable-bitcode 
   ```
   This will build static libraries (`.a` files) for iOS, macOS Intel and ARM64 using OpenSSL v3.5.0

6. If you wish to use "universal" binaries (combining both Intel and ARM64 architectures) for macOS, use these commands:
   
   ```
   lipo -create bin/MacOSXnn.n-x86_64.sdk/lib/libcrypto.a bin/MacOSXnn.n-arm64.sdk/lib/libcrypto.a -output (outputfolder)/libcrypto.a
   lipo -create bin/MacOSXnn.n-x86_64.sdk/lib/libssl.a bin/MacOSXnn.n-arm64.sdk/lib/libssl.a -output (outputfolder)/libssl.a
   ```
   Where:
   `nn.n` should be replaced by the SDK version that the script used (it appears in the build output) e.g. 15.4
   `(outputfolder)` should be replaced with whatever destination folder you wish to have the universal binaries 


