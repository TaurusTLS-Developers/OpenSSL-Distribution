# OpenSSL Distribution

This repository provides **Automated, Cross-Platform Pre-compiled Binaries** for the [OpenSSL 3.x](https://www.openssl.org/) cryptography library.

The binaries are built automatically via GitHub Actions to ensure a clean, reproducible, and secure supply chain.

## 📥 Download

Go to the [**Releases Page**](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/releases) to download the latest artifacts.

## 📦 Artifacts & Structure

We provide two types of packages for every platform (Windows, Linux, macOS, Android).

### 1. Runtime Package
**Filename:** `openssl-{version}-{os}-{arch}.zip` (or `.tar.gz`)
Contains the minimal files required to **run** an application that depends on OpenSSL.

*   **Content:** Shared libraries (`.dll`, `.so`, `.dylib`) and the `openssl` CLI executable.
*   **Optimization:** Binaries are stripped of debug symbols for minimum size.
*   **Relocatable:** Binaries are patched (`$ORIGIN` / `@loader_path`) to find their dependencies in the same directory, regardless of where you install them.

### 2. SDK / Development Package
**Filename:** `openssl-{version}-{os}-{arch}-dev.zip` (or `.tar.gz`)
Contains everything required to **compile** or debug applications against OpenSSL.

**Directory Structure:**
*   `bin/` - Shared libraries and Executables (Same as Runtime).
*   `lib/` - Static libraries (`.lib` for Windows, `.a` for Unix).
*   `include/` - C header files (`.h`).
*   `debug/` - Debug symbols (`.pdb` for Windows, `.dSYM` for macOS, or unstripped `.so` for Linux).
*   `doc/` - HTML documentation (where available).

### Supported Platforms

| Platform | Architecture | Linkage | Notes |
| :--- | :--- | :--- | :--- |
| **Windows** | x86, x64, ARM64 | Static CRT (`/MT`) | Standalone (No VC++ Redistributable needed). |
| **Linux** | x64, ARM64 | Shared & Static | Built on Ubuntu, compatible with glibc distros. |
| **macOS** | x64 (Intel), ARM64 | Shared & Static | Universal support for modern macOS. |
| **Android** | ARM, ARM64, x86, x64 | Shared & Static | Built against recent NDK. |
| **iOS** | ARM64 | Static Only | For linking into iOS Apps. |

## License

These binaries are distributed under the **Apache License 2.0** (OpenSSL 3.0+ standard).
See `LICENSE.txt` inside the archives for details.