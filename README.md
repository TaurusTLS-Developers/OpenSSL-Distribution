# OpenSSL Distribution Packages & Windows Installers

Automated, reproducible, and digitally signed OpenSSL 3.x distribution packages, standalone Windows installers, and cross-platform binary archives compiled for Windows, Linux, macOS, Android, and iOS.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/openssl/openssl/blob/master/LICENSE.txt)

---

## 📦 Distribution Formats

Official releases provide three complementary distribution formats:

| Format | Target Platforms | Key Features | Primary Use Case |
| :--- | :--- | :--- | :--- |
| **Windows Multi-Arch Setup (`.exe`)** | Windows (`x64`, `x86`, `ARM64EC`) | Single installer for all architectures, autodetects CPU, Per-Machine & Per-User modes, Start Menu Command Prompt, optional PATH setup, Azure Signed | End-user systems, system-wide developer CLI setup |
| **MSIX Framework Packages (`.msix`)** | Windows (`x64`, `x86`, `ARM64EC`) | Standalone MSIX Framework packages (`<Framework>true</Framework>`), side-by-side directory isolation, Azure Signed | Packaged Windows applications consuming OpenSSL via `<PackageDependency>` |
| **Unified Portable ZIPs (`.zip`)** | Windows, Linux, macOS, Android, iOS | Portable archives containing shared DLLs/SOs, static libraries (`/lib/static/`), import libraries (`/lib/import/`), headers, and documentation | C/C++ build pipelines, local development, portable bundling |

---

## 🪟 Windows Installers

All Windows binaries, installers, and packages are digitally signed with **Microsoft Azure Trusted Signing** and built using **HybridCRT** (eliminating any external `vcruntime140.dll` dependency).

### 1. InnoSetup Multi-Architecture Installer (`.exe`)
File pattern: `openssl-<version>-Windows-installer.exe`

A single, unified setup executable that contains native binaries for **x64**, **x86**, and **ARM64EC**:

* **Intelligent CPU Detection:** Automatically detects your processor architecture and installs the matching native binaries:
  * **64-bit Intel/AMD (x64):** Installs native 64-bit OpenSSL runtime.
  * **64-bit ARM64 (Surface / Snapdragon):** Installs native ARM64EC OpenSSL runtime.
  * **32-bit (x86):** Installs native 32-bit OpenSSL runtime.
* **32-bit Compatibility Option:** On 64-bit systems, you can check `[x] 32-bit (x86) Compatibility Runtime` to install 32-bit libraries alongside 64-bit libraries for legacy application compatibility (e.g., 32-bit Delphi/C++ applications).
* **Installation Modes & Standard Directories:**
  * **Per-Machine (Admin / All Users):**
    * 64-bit: `C:\Program Files\TaurusTLS Developers\OpenSSL-<version>\`
    * 32-bit: `C:\Program Files (x86)\TaurusTLS Developers\OpenSSL-<version>\`
  * **Per-User (Current User / Non-Admin):**
    * 64-bit: `%LocalAppData%\Programs\TaurusTLS Developers\OpenSSL-<version>\x64\`
    * 32-bit: `%LocalAppData%\Programs\TaurusTLS Developers\OpenSSL-<version>\x86\`
* **OpenSSL Command Prompt:** Adds a Start Menu shortcut that launches a command prompt session directly in the OpenSSL installation folder with `PATH` pre-configured.
* **Silent / Unattended Installation:**
  ~~~cmd
  :: Silent Per-Machine Install (All Users, Default)
  openssl-3.4.0-Windows-installer.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART

  :: Silent Per-User Install (Current User Only)
  openssl-3.4.0-Windows-installer.exe /VERYSILENT /CURRENTUSER /SUPPRESSMSGBOXES /NORESTART
  ~~~

---

### 2. MSIX Framework Packages (`.msix`)
File patterns:
* `openssl-<version>-Windows-x64.msix`
* `openssl-<version>-Windows-x86.msix`
* `openssl-<version>-Windows-arm64ec.msix`

MSIX Framework packages provide isolated, shared runtime libraries for other Windows applications:
* **Isolated Deployment:** Installs directly to `C:\Program Files\WindowsApps\` with complete architecture isolation.
* **MSIX App Dependency:** Consuming applications can reference OpenSSL in their `AppxManifest.xml`:
  ~~~xml
  <Dependencies>
    <PackageDependency Name="TaurusTLS.OpenSSL" MinVersion="3.4.0.0" Publisher="CN=J. Peter Mugaas, O=J. Peter Mugaas, L=Lewisburg, S=wv, C=US" />
  </Dependencies>
  ~~~

---

## 🌐 Cross-Platform Portable ZIP Packages

Every release provides unified `.zip` archives containing the CLI, dynamic modules, static libraries, headers, and documentation.

### Supported Platforms & Architectures

| OS | Architecture | Package Name | Details |
| :--- | :--- | :--- | :--- |
| **Windows** | `x64` | `openssl-<ver>-Windows-x64.zip` | HybridCRT (No `vcruntime140.dll` dependency), Azure Signed |
| **Windows** | `x86` | `openssl-<ver>-Windows-x86.zip` | HybridCRT (No `vcruntime140.dll` dependency), Azure Signed |
| **Windows** | `arm64ec` | `openssl-<ver>-Windows-arm64ec.zip` | Native ARM64EC execution, HybridCRT, Azure Signed |
| **Linux** | `x64` | `openssl-<ver>-Linux-x64.zip` | Dynamic `$ORIGIN` RPATH, SCTP enabled |
| **Linux** | `arm64` | `openssl-<ver>-Linux-arm64.zip` | Dynamic `$ORIGIN` RPATH, aarch64 cross-compiled |
| **macOS** | `universal` | `openssl-<ver>-macOS-universal.zip` | Universal Fat Binaries (`x64` + `arm64`) via `lipo`, relocatable `@rpath` |
| **Android** | `arm64` | `openssl-<ver>-Android-arm64.zip` | 16K page alignment (`max-page-size=16384`), API 21+ |
| **Android** | `arm` | `openssl-<ver>-Android-arm.zip` | 16K page alignment (`max-page-size=16384`), API 21+ |
| **iOS** | `arm64` | `openssl-<ver>-iOS-arm64.zip` | Static archives (`.a`) for physical iOS devices |
| **iOS** | `sim-arm64` | `openssl-<ver>-iOS-sim-arm64.zip` | Static archives (`.a`) for Apple Silicon iOS Simulator |

---

## 📂 Portable Package Directory Layout

All `.zip` packages adhere to a single unified structure:

~~~text
openssl-<version>-<OS>-<Arch>/
├── openssl[.exe]              # OpenSSL CLI utility (Universal on macOS)
├── libcrypto-3*.dll / .so / .dylib # Shared crypto library
├── libssl-3*.dll / .so / .dylib    # Shared SSL/TLS library
├── engines/                   # OpenSSL dynamic engines (.dll / .so / .dylib)
├── providers/                 # OpenSSL dynamic providers (.dll / .so / .dylib)
├── include/                   # C/C++ Header files (openssl/*.h)
├── doc/                       # HTML Documentation
├── lib/
│   ├── import/                # (Windows only) Import libraries (.lib) for dynamic linking
│   └── static/                # True static libraries (.lib / .a)
├── install_symlinks.sh        # (POSIX only) Script to restore shared library symlinks
├── LICENSE.txt                # OpenSSL Apache-2.0 License
├── README.txt                 # Distribution guide
└── version.txt                # Metadata version stamp
~~~

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
Windows file systems fail to extract POSIX symbolic links. To prevent archive extraction corruption, packages contain physical versioned shared library files (e.g., `libcrypto.so.3`). 

On Linux and macOS, run the included script once after extracting to restore standard unversioned symlinks (`libcrypto.so` -> `libcrypto.so.3`):
~~~bash
cd openssl-<version>-<OS>-<Arch>
sh ./install_symlinks.sh
~~~

---

## 🔒 Code Signing & Verification

All Windows binaries, `.exe` installers, and `.msix` packages are digitally signed via **Microsoft Azure Trusted Signing**.

To verify the signature of any Windows binary, installer, or package:
~~~powershell
Get-AuthenticodeSignature .\openssl.exe
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-installer.exe
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-x64.msix
~~~

---

## 🔄 Automated Upstream Tracking

This repository automatically checks the [official OpenSSL releases](https://github.com/openssl/openssl/releases) daily via `check-upstream.yml`. When a new supported release is detected:
1. Validates that the branch has not reached End-of-Life (EOL).
2. Triggers automated cross-platform compilation and code signing.
3. Builds and signs the Windows InnoSetup and MSIX installers.
4. Packages and publishes the release assets automatically.

---

## 📄 License

* **OpenSSL:** Licensed under the [Apache License 2.0](https://github.com/openssl/openssl/blob/master/LICENSE.txt).
* **Distribution Scripts & Tools:** Licensed under the [MIT License](LICENSE).
