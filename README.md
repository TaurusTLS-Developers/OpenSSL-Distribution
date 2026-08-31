# OpenSSL Distribution Packages & Windows Installers

Automated, reproducible, and digitally signed OpenSSL 3.x distribution packages, standalone Windows installers, and cross-platform binary archives compiled for Windows, Linux, macOS, Android, and iOS.

[![Build OpenSSL](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/actions/workflows/build-openssl.yml/badge.svg)](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/actions/workflows/build-openssl.yml)
[![Check Upstream](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/actions/workflows/check-upstream.yml/badge.svg)](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/actions/workflows/check-upstream.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/openssl/openssl/blob/master/LICENSE.txt)

---

## 📦 Distribution Formats

Official releases provide three complementary distribution formats:

| Format | Target Platforms | Key Features | Primary Use Case |
| :--- | :--- | :--- | :--- |
| **Windows Multi-Arch Setup (`.exe`)** | Windows (`x64`, `x86`, `ARM64`) | Single installer for all architectures, autodetects CPU, Per-Machine & Per-User modes, Start Menu Command Prompt, optional PATH setup, Azure Signed | End-user systems, system-wide developer CLI setup |
| **MSIX Framework Packages (`.msix`)** | Windows (`x64`, `x86`, `ARM64`) | Standalone MSIX Framework packages (`<Framework>true</Framework>`), side-by-side directory isolation, Azure Signed | Packaged Windows applications consuming OpenSSL via `<PackageDependency>` |
| **Unified Portable ZIPs (`.zip`)** | Windows, Linux, macOS, Android, iOS | Portable archives containing shared DLLs/SOs/dylibs, static libraries (`/lib/static/`), import libraries (`/lib/import/`), headers, and documentation | C/C++ build pipelines, local development, portable bundling |

---

## 🍎 macOS Universal (Unified) Binaries

File pattern: `openssl-<version>-macOS-universal.zip`

Our macOS release is delivered as a **single, unified package** designed for both local development and seamless app bundle redistribution across the entire Mac ecosystem:

* **Single Package, Two Architectures:** Contains true **Universal (Fat) Mach-O binaries** combining both **`x86_64` (Intel)** and **`arm64` (Apple Silicon M-series)** code into single binary files via `lipo`.
* **Universal Static Linking:** Includes unified static archives (`libcrypto.a` and `libssl.a`). You can link your application against them to compile native apps for Intel Macs, Apple Silicon Macs, or Universal binaries without managing multiple library paths.
* **Fully Relocatable Shared Libraries (`.dylib`):** All shared libraries, engines, and providers are pre-configured with relative Mach-O install names (`@rpath`, `@loader_path`, and `@executable_path`). They are 100% drop-in ready to be embedded directly inside macOS `.app` application bundles without requiring path adjustments.
* **Stripped & Clean:** Stripped of non-global debugging symbols (`strip -x` / `strip -S`) to keep your application footprint small. Packaged without fragile symlinks to ensure clean extraction on all file systems (includes `install_symlinks.sh` for optional local dev setup).

---

## ⚡ Windows ARM64X Dual-Architecture Technology

File pattern: `openssl-<version>-Windows-arm64.zip`

Windows ARM64 releases feature true **ARM64X** dual-architecture binaries:
* **Single Binary, Dual Execution:** `libcrypto-3-arm64.dll`, `libssl-3-arm64.dll`, providers, and engines contain both **Native ARM64** and **ARM64EC** (x64-compatible) code slices in a single binary image.
* **Unified Import & Static Libraries:** The default `lib/import/libcrypto.lib` and `lib/static/libcrypto.lib` are unified ARM64X archives that link seamlessly in both Native ARM64 and ARM64EC projects.
* **Dedicated Slices Included:** For toolchains requiring pure single-architecture archives, dedicated subfolders (`lib/import/arm64/`, `lib/import/arm64ec/`, `lib/static/arm64/`, `lib/static/arm64ec/`) are included in the package.

---

## 🪟 Windows Installers

All Windows binaries, installers, and packages are digitally signed with **Microsoft Azure Trusted Signing** and built using **HybridCRT** (eliminating any external `vcruntime140.dll` dependency).

### 1. InnoSetup Multi-Architecture Installer (`.exe`)
File pattern: `openssl-<version>-Windows-installer.exe`

A single setup executable containing native binaries for **x64**, **x86**, and **ARM64** (ARM64X):

* **Intelligent Architecture Detection:** Detects the host processor architecture at install time and deploys matching native binaries:
  * **64-bit Intel/AMD (x64):** Installs native 64-bit OpenSSL runtime into `bin64`.
  * **64-bit ARM64 (Surface / Snapdragon):** Installs native ARM64 / ARM64X OpenSSL runtime into `bin64`.
  * **32-bit (x86):** Installs native 32-bit OpenSSL runtime into `bin32`.
* **32-bit Compatibility Option:** On 64-bit systems, users can check `[x] 32-bit (x86) Compatibility Runtime` to install 32-bit libraries into `bin32` alongside 64-bit libraries for legacy application compatibility (e.g., 32-bit Delphi/C++ applications).
* **Installation Modes & Directory Layouts:**
  * **Per-Machine (Admin / All Users):**
    * 64-bit: `C:\Program Files\TaurusTLS Developers\OpenSSL-<version>\bin64\`
    * 32-bit: `C:\Program Files (x86)\TaurusTLS Developers\OpenSSL-<version>\bin32\`
  * **Per-User (Current User / Non-Admin):**
    * 64-bit: `%LocalAppData%\Programs\TaurusTLS Developers\OpenSSL-<version>\bin64\`
    * 32-bit: `%LocalAppData%\Programs\TaurusTLS Developers\OpenSSL-<version>\bin32\`
* **OpenSSL Command Prompt:** Adds a Start Menu shortcut that launches a command prompt session directly in the OpenSSL installation folder with `PATH` pre-configured.
* **Silent / Unattended Installation:**
  ```cmd
  :: Silent Per-Machine Install (All Users, Default)
  openssl-3.4.0-Windows-installer.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART

  :: Silent Per-User Install (Current User Only)
  openssl-3.4.0-Windows-installer.exe /VERYSILENT /CURRENTUSER /SUPPRESSMSGBOXES /NORESTART
  ```

---

### 2. MSIX Framework Packages (`.msix`)
File patterns:
* `openssl-<version>-Windows-x64.msix`
* `openssl-<version>-Windows-x86.msix`
* `openssl-<version>-Windows-arm64.msix`

MSIX Framework packages provide isolated, shared runtime libraries for other Windows applications:
* **Isolated Deployment:** Installs directly to `C:\Program Files\WindowsApps\` with complete architecture isolation.
* **MSIX App Dependency:** Consuming applications can reference OpenSSL in their `AppxManifest.xml`:
  ```xml
  <Dependencies>
    <PackageDependency Name="TaurusTLS.OpenSSL" MinVersion="3.4.0.0" Publisher="CN=..." />
  </Dependencies>
  ```

---

## 🌐 Cross-Platform Portable ZIP Packages

Every release provides unified `.zip` archives containing the CLI, dynamic modules, static libraries, headers, and documentation.

### Supported Platforms & Architectures

| OS | Architecture | Package Name | Details |
| :--- | :--- | :--- | :--- |
| **Windows** | `x64` | `openssl-<ver>-Windows-x64.zip` | HybridCRT (No `vcruntime140.dll` dependency), Azure Signed |
| **Windows** | `x86` | `openssl-<ver>-Windows-x86.zip` | HybridCRT (No `vcruntime140.dll` dependency), Azure Signed |
| **Windows** | `arm64` | `openssl-<ver>-Windows-arm64.zip` | True ARM64X (Native ARM64 + ARM64EC), HybridCRT, Azure Signed |
| **macOS** | `universal` | `openssl-<ver>-macOS-universal.zip` | Universal Fat Binaries (`x64` + `arm64`) via `lipo`, relocatable `@rpath` |
| **Linux** | `x64` | `openssl-<ver>-Linux-x64.zip` | Dynamic `$ORIGIN` RPATH, SCTP enabled |
| **Linux** | `arm64` | `openssl-<ver>-Linux-arm64.zip` | Dynamic `$ORIGIN` RPATH, aarch64 cross-compiled |
| **Android** | `arm64` | `openssl-<ver>-Android-arm64.zip` | 16K page alignment (`max-page-size=16384`), API 21+ |
| **Android** | `arm` | `openssl-<ver>-Android-arm.zip` | 16K page alignment (`max-page-size=16384`), API 21+ |
| **iOS** | `arm64` | `openssl-<ver>-iOS-arm64.zip` | Static archives (`.a`) for physical iOS devices |
| **iOS** | `sim-arm64` | `openssl-<ver>-iOS-sim-arm64.zip` | Static archives (`.a`) for Apple Silicon iOS Simulator |

---

## 📂 Portable Package Directory Layout

All `.zip` packages adhere to a single unified structure:

```text
openssl-<version>-<OS>-<Arch>/
├── openssl[.exe]              # OpenSSL CLI utility (Native ARM64 on Win-ARM64, Universal on macOS)
├── libcrypto-3*.dll / .so / .dylib # Shared crypto library
├── libssl-3*.dll / .so / .dylib    # Shared SSL/TLS library
├── engines/                   # OpenSSL dynamic engines (.dll / .so / .dylib)
├── providers/                 # OpenSSL dynamic providers (.dll / .so / .dylib)
├── include/                   # C/C++ Header files (openssl/*.h)
├── doc/                       # HTML Documentation
├── lib/
│   ├── import/                # (Windows only) Import libraries (.lib) for dynamic linking
│   │   ├── arm64/             # (Win-ARM64 only) Dedicated Native ARM64 import libs
│   │   └── arm64ec/           # (Win-ARM64 only) Dedicated ARM64EC import libs
│   └── static/                # True static libraries (.lib / .a)
│       ├── arm64/             # (Win-ARM64 only) Dedicated Native ARM64 static libs
│       └── arm64ec/           # (Win-ARM64 only) Dedicated ARM64EC static libs
├── install_symlinks.sh        # (POSIX only) Script to restore shared library symlinks
├── LICENSE.txt                # OpenSSL Apache-2.0 License
├── README.txt                 # Distribution guide
└── version.txt                # Metadata version stamp
```

---

## 🔗 Linking Instructions

### Windows (MSVC, Delphi, C++Builder)
* **Dynamic Linking (Recommended):** Link against the import libraries in `lib/import/` (e.g., `libcrypto.lib`, `libssl.lib`). Ship the root `.dll` files alongside your executable.
* **Static Linking:** Link against the static libraries in `lib/static/`. These are compiled with `/MT` HybridCRT to link against Windows' native `ucrtbase.dll`.

### macOS (Intel & Apple Silicon)
* **Universal Binaries:** All binaries and static archives contain combined `x86_64` and `arm64` slices. You can link against them from both Intel and Apple Silicon Macs.
* **Relocatable `@rpath`:** Shared libraries have pre-configured `@rpath` IDs for easy app bundle embedding.

### Linux & Unix
* **Dynamic Linking:** Link against `libcrypto.so.3` / `libssl.so.3`. Libraries are built with `-Wl,-rpath,'$ORIGIN'` to load adjacent dependencies automatically.
* **Static Linking:** Link against `lib/static/libcrypto.a` and `lib/static/libssl.a`.

### POSIX Symlink Restoration
Windows file systems fail to extract POSIX symbolic links. To prevent archive extraction corruption, packages contain physical versioned shared library files (e.g., `libcrypto.so.3` or `libcrypto.3.dylib`). 

On Linux and macOS, run the included script once after extracting to restore standard unversioned symlinks (`libcrypto.so` -> `libcrypto.so.3` or `libcrypto.dylib` -> `libcrypto.3.dylib`):
```bash
cd openssl-<version>-<OS>-<Arch>
sh ./install_symlinks.sh
```

---

## 🔒 Code Signing & Verification

All Windows binaries, `.exe` installers, and `.msix` packages are digitally signed via **Microsoft Azure Trusted Signing**.

To verify the signature of any Windows binary, installer, or package:
```powershell
Get-AuthenticodeSignature .\openssl.exe
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-installer.exe
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-x64.msix
```

---

## 🔄 Automated Upstream Tracking

This repository automatically checks the [official OpenSSL releases](https://github.com/openssl/openssl/releases) daily via `check-upstream.yml`. When a new supported release is detected:
1. Validates that the branch has not reached End-of-Life (EOL).
2. Triggers automated cross-platform compilation and code signing across all targets.
3. Fuses ARM64X binaries and macOS Universal binaries.
4. Builds and signs the Windows InnoSetup and MSIX installers.
5. Packages and publishes the release assets automatically.

---

## 📄 License

* **OpenSSL:** Licensed under the [Apache License 2.0](https://github.com/openssl/openssl/blob/master/LICENSE.txt).
* **Distribution Scripts & Tools:** Licensed under the [MIT License](LICENSE).