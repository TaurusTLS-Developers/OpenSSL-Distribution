# OpenSSL Distribution

This repository provides **Automated, Cross-Platform Pre-compiled Binaries** for the [OpenSSL 3.x](https://www.openssl.org/) cryptography library.

The binaries are built automatically via GitHub Actions to ensure a clean, reproducible, and secure supply chain.

## 📥 Download

Go to the [**Releases Page**](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/releases) to download the latest artifacts.

## 📦 Artifacts & Structure

We provide a **Single Unified Package** for every platform (Windows, Linux, macOS, Android, iOS). This package contains everything needed for both runtime redistribution and software development (dynamic and static linking).

**Filename Pattern:** `openssl-{version}-{os}-{arch}.zip`

### Package Layout
| | |
| :--- | :--- |
|`version.txt`|Contains OpenSSL Version number|
|`openssl`|The OpenSSL command-line utility|
|`libcrypto` / `libssl`|Shared libraries|
|`install_symlinks.sh`|(POSIX only) Script to restore shared library symlinks|
|`engines/`|OpenSSL engines|
|`providers/`|OpenSSL providers|
|`doc/`|Developers Documentation|
|`include/`|C Header files|
|`lib/import/`|Import libraries (Windows only)|
|`lib/static/`|Static libraries (`.lib` / `.a`)|
| | |
### 🚀 Deployment Instructions

When redistributing OpenSSL alongside your application, you only need to deploy a specific subset of the files provided in this package.

#### 🔴 REQUIRED (Must be deployed)
These files are strictly required for your application to run and to comply with licensing.
*   **`libcrypto`** shared library (e.g., `libcrypto-3-x64.dll`, `libcrypto.so.3`, `libcrypto.3.dylib`)
*   **`libssl`** shared library (e.g., `libssl-3-x64.dll`, `libssl.so.3`, `libssl.3.dylib`)
*   **`LICENSE.txt`** (Required by the Apache License 2.0)

#### 🟡 OPTIONAL (Deploy only if needed)
Include these only if your application explicitly relies on them.
*   **`openssl` / `openssl.exe`** (The standalone command-line utility)
*   **`engines/`** (Legacy hardware/engine support modules)
*   **`providers/`** (OpenSSL 3.x provider modules, such as `legacy.dll` / `legacy.so`)

#### ⛔ DO NOT DEPLOY (Development only)
These files are for compiling/linking your software and should **not** be shipped to end-users.
*   **`include/`** (C headers)
*   **`lib/`** (Static and Import libraries)
*   **`doc/`** (HTML Documentation)
*   **`README.txt`**

#### 🐧 POSIX Specifics (Linux / macOS / Unix)
Windows file systems often fail to extract Unix symbolic links. To ensure cross-platform compatibility, our archives contain **only the physical shared library files** (no symlinks).

If your package includes the `install_symlinks.sh` script, you **MUST** run it from the root of the extracted directory on your target POSIX system to recreate the required library symlinks (e.g., `libcrypto.so` -> `libcrypto.so.3`).

```bash
$ cd <extracted_directory>
$ sh ./install_symlinks.sh
```

*(Note: Windows users do not use symlinks for OpenSSL DLLs and can safely ignore or delete this shell script.)*

### Linking Instructions (For Developers)

*   **Windows Dynamic:** Link against the import libraries in `lib/import/` (which point to the DLLs in the root).
*   **Windows Static:** Link against the static libraries in `lib/static/`. *Note: These are compiled with the `/MD` (Dynamic CRT) flag for seamless integration into modern MSVC projects.*
*   **POSIX Dynamic:** Link directly against the shared libraries (`.so` / `.dylib`) in the root directory.
*   **POSIX Static:** Link against the static archives (`.a`) in `lib/static/`.


### Technical Details & Optimizations
*   **No Debug Symbols:** All binaries (shared and static) are stripped of debug symbols (`.pdb`, `.dSYM`) to minimize package size.
*   **Relocatable:** Shared libraries are patched (`$ORIGIN` on Linux/Android, `@loader_path`/`@rpath` on macOS) to find their dependencies in the same directory.
*   **Android 16K:** Android shared libraries are compiled with 16K page alignment support (`-Wl,-z,max-page-size=16384`).

### Supported Platforms

| Platform | Architecture | Linkage | Notes |
| :--- | :--- | :--- | :--- |
| **Windows** | x86, x64, ARM64EC | Shared & Static | Built for `Windows 10`/`Windows Server 2016` and higher.<br/>ARM64EC builds are **strictly experimental** as OpenSSL does not support this platform yet.<br/> __See[OpenSSL Issue #16482](https://github.com/openssl/openssl/issues/16482) for additional details__  |
| **Linux** | x64, ARM64 | Shared & Static | Built on Ubuntu, compatible with glibc distros. SCTP enabled. |
| **macOS** | x64 (Intel), ARM64 | Shared & Static | Universal support for modern macOS. |
| **Android** | ARM64, x64 | Shared & Static | Built against recent NDK. |
| **iOS** | ARM64 | Static Only | For linking into iOS Apps. |
| | | | |

## License

These binaries are distributed under the **Apache License 2.0** (OpenSSL 3.0+ standard).
See `LICENSE.txt` inside the archives for details.
