# OpenSSL Distribution

This repository provides **Automated, Cross-Platform Pre-compiled Binaries** for the [OpenSSL 3.x](https://www.openssl.org/) cryptography library.

The binaries are built automatically via GitHub Actions to ensure a clean, reproducible, and secure supply chain.

## 📥 Download

Go to the [**Releases Page**](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/releases) to download the latest artifacts.


## 📦 Artifacts & Structure

We provide two distinct types of packages for every platform (Windows, Linux, macOS, Android). Please choose the one that matches your linking requirements.

### 1. Redistributable Package (Runtime)
**Filename Pattern:** `openssl-{version}-{os}-{arch}.zip` (or `.tar.gz`)

Use this package if your application uses **Dynamic Linking** (e.g., standard Windows applications).

*   **Purpose:** Contains the files required to **run** an application.
*   **Contents:** Shared libraries (`.dll`, `.so`, `.dylib`) and the `openssl` CLI executable.
*   **Redistribution:** You can redistribute these files alongside your application.
*   **Optimization:** Binaries are stripped of debug symbols for minimum size.
*   **Relocatable:** Binaries are patched (`$ORIGIN` / `@loader_path`) to find their dependencies in the same directory.

### 2. Development Package (Static Linking & SDK)
**Filename Pattern:** `openssl-{version}-{os}-{arch}-dev.zip` (or `.tar.gz`)

Use this package if you are a developer compiling an application with **Static Linking** (e.g., Android, iOS, or macOS).

*   **Purpose:** Contains the files required to **compile** or debug applications.
*   **Contents:**
    *   `debug/` - Debug symbols (`.pdb`, `.dSYM`).
    *   `doc/` - HTML documentation.
    *   `include/` - C header files (`.h`).
    *   `static/` - **Static libraries** (`.a` for Unix/Mobile, `.lib` for Windows) required for static linking.
    *   `shared/` - Unstipped (for POSIX platforms) shared libraries and Executables (Same as Runtime).

### Supported Platforms

| Platform | Architecture | Linkage | Notes |
| :--- | :--- | :--- | :--- |
| **Windows** | x86, x64, ARM64EC | Shared & Static | Built for `Windows 10`/`Windows Server 2016` and higher.<br/>ARM64EC builds are **strictly experimental** as OpenSSL does not support this platfrom yet.<br/> __See [OpenSSL Issue #16482](https://github.com/openssl/openssl/issues/16482) for additional details__  |
| **Linux** | x64, ARM64 | Shared & Static | Built on Ubuntu, compatible with glibc distros. |
| **macOS** | x64 (Intel), ARM64 | Shared & Static | Universal support for modern macOS. |
| **Android** | ARM, ARM64, x86, x64 | Shared & Static | Built against recent NDK. |
| **iOS** | ARM64 | Static Only | For linking into iOS Apps. |

## License

These binaries are distributed under the **Apache License 2.0** (OpenSSL 3.0+ standard).
See `LICENSE.txt` inside the archives for details.
