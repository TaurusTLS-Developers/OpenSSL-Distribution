# OpenSSL Distribution Packages & Windows Installers

Automated, reproducible, and digitally signed OpenSSL 3.x distribution packages, standalone Windows installers, and cross-platform binary archives compiled for Windows, Linux, macOS, Android, and iOS.

[![GitHub Release](https://img.shields.io/github/v/release/TaurusTLS-Developers/OpenSSL-Distribution?color=blue&label=Latest%20Release)](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/releases/latest)
[![GitHub Downloads](https://img.shields.io/github/downloads/TaurusTLS-Developers/OpenSSL-Distribution/total?color=green&label=Downloads)](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/releases)
[![Azure Trusted Signing](https://img.shields.io/badge/Code%20Signing-Azure%20Trusted%20Signing-0078D4?logo=microsoftazure)](https://azure.microsoft.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/openssl/openssl/blob/master/LICENSE.txt)

[![GitHub Stars](https://img.shields.io/github/stars/TaurusTLS-Developers/OpenSSL-Distribution?style=social)](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/stargazers) 
> ⭐ **Love this project?** Give it a star on GitHub! It helps more developers find pre-compiled, signed, and zero-dependency OpenSSL binaries.
---

## 💡 Why Choose This OpenSSL Distribution?

| Feature | Compiling from Source | Legacy OpenSSL Binaries | **TaurusTLS OpenSSL** |
| :--- | :---: | :---: | :---: |
| **No `vcruntime140.dll` Dependency** | ❌ (Requires `/MD` CRT) | ❌ (Causes missing DLL error) | ✅ **HybridCRT (Zero dependencies)** |
| **Windows ARM64X Dual-Architecture** | ❌ (Complex dual-linking) | ❌ | ✅ **Native ARM64 + ARM64EC in one DLL** |
| **Microsoft Azure Trusted Signing** | ❌ | ❌ (Triggers SmartScreen) | ✅ **Digitally Signed (`.exe`, `.dll`, `.msi`, `.msix`)** |
| **Installer Variety** | ❌ | ⚠️ (Single `.exe`) | ✅ **Multi-Arch InnoSetup, WiX MSI & MSIX** |
| **macOS Universal Binaries** | ❌ (Requires manual `lipo`) | ⚠️ | ✅ **Combined `x86_64` + `arm64` (`@rpath` ready)** |
| **Android 16K Page Alignment** | ❌ (Defaults to 4KB) | ❌ | ✅ **Android 15+ 16KB Page Aligned** |
| **Automated Upstream Tracking** | ❌ | ⚠️ (Manual updates) | ✅ **Built within 24h of OpenSSL releases** |

---

## 📦 Distribution Formats

Official releases provide four complementary distribution formats:

| Format | Target Platforms | Key Features | Primary Use Case |
| :--- | :--- | :--- | :--- |
| **Windows Multi-Arch Setup (`.exe`)** | Windows (`x64`, `x86`, `ARM64`) | Single installer for all architectures, autodetects CPU, Per-Machine & Per-User modes, Start Menu Command Prompt, optional PATH setup, Azure Signed | End-user systems, interactive workstation setup |
| **Windows MSI Installers (`.msi`)** | Windows (`x64`, `x86`, `ARM64`) | Built with WiX Toolset, GPO/Intune enterprise deployment, automated rollback & repair, interactive feature tree with optional 32-bit runtime on x64, Azure Signed | Enterprise IT deployment, automated Active Directory / Intune rollout |
| **MSIX Framework Packages (`.msix`)** | Windows (`x64`, `x86`, `ARM64`) | Standalone MSIX Framework packages (`<Framework>true</Framework>`), side-by-side directory isolation, Azure Signed | Packaged Windows applications consuming OpenSSL via `<PackageDependency>` |
| **Unified Portable ZIPs (`.zip`)** | Windows, Linux, macOS, Android, iOS | Portable archives containing shared DLLs/SOs/dylibs, static libraries (`/lib/static/`), import libraries (`/lib/import/`), headers, and documentation | C/C++ build pipelines, local development, portable bundling |

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
* **32-bit Compatibility Option:** On 64-bit systems, users can check `[x] 32-bit (x86) Compatibility Runtime` to install 32-bit libraries into `bin32` alongside 64-bit libraries for legacy application compatibility.
* **Installation Modes & Directory Layouts:**
  * **Per-Machine (Admin / All Users):**
    * 64-bit / ARM64: `C:\Program Files\TaurusTLS Developers\OpenSSL-<major.minor>\bin64\`
    * 32-bit: `C:\Program Files (x86)\TaurusTLS Developers\OpenSSL-<major.minor>\bin32\`
  * **Per-User (Current User / Non-Admin):**
    * 64-bit / ARM64: `%LocalAppData%\Programs\TaurusTLS Developers\OpenSSL-<major.minor>\x64\`
    * 32-bit: `%LocalAppData%\Programs\TaurusTLS Developers\OpenSSL-<major.minor>\x86\`
* **OpenSSL Command Prompt:** Adds a Start Menu shortcut that launches a command prompt session directly in the OpenSSL installation folder with `PATH` pre-configured.
* **Silent Installation:**
  ```cmd
  :: Silent Per-Machine Install (All Users, Default)
  openssl-3.4.0-Windows-installer.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART

  :: Silent Per-User Install (Current User Only)
  openssl-3.4.0-Windows-installer.exe /VERYSILENT /CURRENTUSER /SUPPRESSMSGBOXES /NORESTART
  ```

---

### 2. WiX Windows MSI Installers (`.msi`)
File patterns:
* `openssl-<version>-Windows-x64.msi`
* `openssl-<version>-Windows-x86.msi`
* `openssl-<version>-Windows-arm64.msi`

Enterprise-ready Windows Installer (`.msi`) packages built using modern **WiX Toolset**:
* **Enterprise Management:** Fully compatible with Active Directory Group Policy Objects (GPO), Microsoft Intune, and Microsoft Endpoint Configuration Manager (SCCM).
* **Transaction Safety & Self-Healing:** Powered by the Windows Installer database engine with automatic rollback on installation interruption and on-demand repair.
* **Interactive Feature Selection Tree:**
  * 📦 **OpenSSL Native Runtime:** Installs native binaries into `%ProgramFiles%\TaurusTLS Developers\OpenSSL-<major.minor>\` (customizable via `Browse...`).
    * └── 📦 **Add native directory to PATH:** Optional sub-feature to add the installation folder to the system `PATH`.
  * 📦 **32-bit (x86) Compatibility Runtime (on x64 MSI):** Optional feature to install 32-bit libraries into `%ProgramFiles(x86)%\TaurusTLS Developers\OpenSSL-<major.minor>\` (customizable via `Browse...`).
    * └── 📦 **Add 32-bit directory to PATH:** Optional sub-feature to add the 32-bit folder to the system `PATH`.
* **In-Place Upgrades:** Uses deterministic upgrade codes scoped by `Major.Minor` so that patch releases (e.g. `3.0.23` over `3.0.22`) upgrade in-place, while major/minor releases (e.g. `3.0` vs `3.5`) coexist side-by-side.
* **Silent Command-Line Installation:**
  ```cmd
  :: Silent Administrative Install
  msiexec /i openssl-3.4.0-Windows-x64.msi /qn /norestart

  :: Silent Install with Verbose Logging
  msiexec /i openssl-3.4.0-Windows-x64.msi /qn /norestart /l*v "openssl_install.log"
  ```

---

### 3. MSIX Framework Packages (`.msix`)
File patterns:
* `openssl-<version>-Windows-x64.msix`
* `openssl-<version>-Windows-x86.msix`
* `openssl-<version>-Windows-arm64.msix`

MSIX Framework packages provide isolated, shared runtime libraries for other Windows applications:
* **Isolated Deployment:** Installs directly to `C:\Program Files\WindowsApps\` with complete architecture isolation.
* **MSIX App Dependency:** Consuming applications can reference OpenSSL in their `AppxManifest.xml`:
  ```xml
  <Dependencies>
    <PackageDependency Name="TaurusTLS.OpenSSL.3.4" MinVersion="3.4.0.0" Publisher="CN=..." />
  </Dependencies>
  ```

---

## ⚡ Windows ARM64X Dual-Architecture Technology

File pattern: `openssl-<version>-Windows-arm64.zip`

Windows ARM64 releases feature true **ARM64X** dual-architecture binaries:
* **Single Binary, Dual Execution:** `libcrypto-3-arm64.dll`, `libssl-3-arm64.dll`, providers, and engines contain both **Native ARM64** and **ARM64EC** (x64-compatible) code slices in a single binary image.
* **Unified Import & Static Libraries:** The default `lib/import/libcrypto.lib` and `lib/static/libcrypto.lib` are unified ARM64X archives that link seamlessly in both Native ARM64 and ARM64EC projects.
* **Dedicated Slices Included:** For toolchains requiring pure single-architecture archives, dedicated subfolders (`lib/import/arm64/`, `lib/import/arm64ec/`, `lib/static/arm64/`, `lib/static/arm64ec/`) are included in the package.

---

## 🍎 macOS Universal (Unified) Binaries

File pattern: `openssl-<version>-macOS-universal.zip`

Our macOS release is delivered as a **single, unified package** designed for both local development and seamless app bundle redistribution across the entire Mac ecosystem:

* **Single Package, Two Architectures:** Contains true **Universal (Fat) Mach-O binaries** combining both **`x86_64` (Intel)** and **`arm64` (Apple Silicon M-series)** code into single binary files via `lipo`.
* **Universal Static Linking:** Includes unified static archives (`libcrypto.a` and `libssl.a`). You can link your application against them to compile native apps for Intel Macs, Apple Silicon Macs, or Universal binaries without managing multiple library paths.
* **Fully Relocatable Shared Libraries (`.dylib`):** All shared libraries, engines, and providers are pre-configured with relative Mach-O install names (`@rpath`, `@loader_path`, and `@executable_path`). They are 100% drop-in ready to be embedded directly inside macOS `.app` application bundles without requiring path adjustments.
* **Stripped & Clean:** Stripped of non-global debugging symbols (`strip -x` / `strip -S`). Includes `install_symlinks.sh` for optional local dev setup.

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

### Linux & Unix
* **Dynamic Linking:** Link against `libcrypto.so.3` / `libssl.so.3`. Libraries are built with `-Wl,-rpath,'$ORIGIN'` to load adjacent dependencies automatically.
* **Static Linking:** Link against `lib/static/libcrypto.a` and `lib/static/libssl.a`.

### macOS (Intel & Apple Silicon)
* **Universal Binaries:** All binaries and static archives contain combined `x86_64` and `arm64` slices. You can link against them from both Intel and Apple Silicon Macs.
* **Relocatable `@rpath`:** Shared libraries have pre-configured `@rpath` IDs for easy app bundle embedding.

### POSIX Symlink Restoration
Windows file systems fail to extract POSIX symbolic links. To prevent archive extraction corruption, packages contain physical versioned shared library files (e.g., `libcrypto.so.3` or `libcrypto.3.dylib`). 

On Linux and macOS, run the included script once after extracting to restore standard unversioned symlinks (`libcrypto.so` -> `libcrypto.so.3` or `libcrypto.dylib` -> `libcrypto.3.dylib`):
```bash
cd openssl-<version>-<OS>-<Arch>
sh ./install_symlinks.sh
```

---

## 🔒 Code Signing & Verification

All Windows binaries, `.exe` installers, `.msi` installers, and `.msix` packages are digitally signed via **Microsoft Azure Trusted Signing**.

To verify the signature of any Windows artifact:
```powershell
Get-AuthenticodeSignature .\openssl.exe
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-installer.exe
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-x64.msi
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-x64.msix
```

---

## 🔄 Automated Upstream Tracking

This repository automatically checks the [official OpenSSL releases](https://github.com/openssl/openssl/releases) daily via `check-upstream.yml`. When a new supported release is detected:
1. Validates that the branch has not reached End-of-Life (EOL).
2. Triggers automated cross-platform compilation and code signing across all targets.
3. Fuses ARM64X binaries and macOS Universal binaries.
4. Builds and signs the Windows InnoSetup, WiX MSI, and MSIX installers.
5. Packages and publishes the release assets automatically.

---

## 📄 License

* **OpenSSL:** Licensed under the [Apache License 2.0](https://github.com/openssl/openssl/blob/master/LICENSE.txt).
* **Distribution Scripts & Tools:** Licensed under the [MIT License](LICENSE).
