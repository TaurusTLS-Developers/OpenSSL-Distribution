# OpenSSL Distribution — Maintainer Guide & CI/CD Architecture

This document provides complete operational, architectural, and configuration documentation for maintaining the automated OpenSSL 3.x cross-platform compilation, code signing, packaging, and release pipeline.

---

## Table of Contents
1. [Pipeline Overview & Architecture](#1-pipeline-overview--architecture)
2. [Windows HybridCRT Architecture](#2-windows-hybridcrt-architecture)
3. [Windows ARM64X Dual-Architecture Pipeline](#3-windows-arm64x-dual-architecture-pipeline)
4. [macOS Universal (Unified) Binary Pipeline](#4-macos-universal-unified-binary-pipeline)
5. [Azure Trusted Signing (Artifact Signing) Setup](#5-azure-trusted-signing-artifact-signing-setup)
6. [Windows Installers (InnoSetup, MSIX & WiX MSI)](#6-windows-installers-innosetup-msix--wix-msi)
7. [Templates & Visual Branding Assets](#7-templates--visual-branding-assets)
8. [Repository Configuration: Secrets & Variables](#8-repository-configuration-secrets--variables)
9. [Release & Publishing Automation](#9-release--publishing-automation)
10. [Troubleshooting & Common Maintenance Scenarios](#10-troubleshooting--common-maintenance-scenarios)

---

## 1. Pipeline Overview & Architecture

The build pipeline (`.github/workflows/build-openssl.yml`) uses a parallelized **Fan-Out / Fan-In** architecture divided into five stages:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 0. Validate Version & EOL Gate (endoflife.date API validation)              │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. Build Common Assets (Headers, HTML Docs, License.txt & License.rtf)      │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2.Compile Binaries (Fan-Out Matrix: Win x64/x86, Linux, macOS, Android, iOS)│
│    2b. Compile ARM64X Slices (Native ARM64 + ARM64EC parallel compilation)  │
│    2c. Merge & Sign ARM64X (Fuse static/import libs & link ARM64X DLLs)     │
└──────────────┬───────────────────┬───────────────────┬──────────────┬───────┘
               │                   │                   │              │
               ▼                   ▼                   ▼              ▼
┌───────────────────────┐ ┌─────────────────┐ ┌─────────────┐ ┌───────────────┐
│ 3a. InnoSetup Setup   │ │ 3b. MSIX Frames │ │ 3c. WiX MSI │ │ 4. Package    │
│ Multi-Arch EXE Setup  │ │ x64,x86,ARM64   │ │ x64,x86,ARM │ │ ZIPs + lipo   │
└──────────────┬────────┘ └────────┬────────┘ └───────┬─────┘ └───────┬───────┘
               │                   │                  │               │
               └───────────────────┼──────────────────┴───────────────┘
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 5. Cleanup Intermediate Artifacts (gh api -X DELETE raw/slice artifacts)    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Stage Summary
* **Stage 0: Validate Version:** Validates version against OpenSSL releases or Git branch/tag SHAs. Verifies EOL date via `endoflife.date` API. Generates deterministic `MAJOR_MINOR` and `INNO_APP_ID` identifiers.
* **Stage 1: Build Common Assets:** Compiles C headers (`include/`), HTML documentation (`doc/`), `README.txt`, plain-text `LICENSE.txt`, and generates formatted `LICENSE.rtf` once on a fast Linux runner.
* **Stage 2: Compile Binaries (Fan-Out):** Compiles raw shared and static libraries across Windows (`x64`, `x86`), Linux (`x64`, `arm64`), macOS (`x64`, `arm64`), Android (`arm64`, `arm`), and iOS (`arm64`, `sim-arm64`).
* **Stage 2b & 2c: Windows ARM64X Pipeline:** Compiles Native `ARM64` and `ARM64EC` slices in parallel, fuses them into true `AA64 (ARM64X)` binaries with embedded `DVRT` relocation tables, and signs them.
* **Stage 3: Windows Installers (Release Builds Only):**
  * `InnoSetup-windows-installer`: Generates a single multi-architecture `.exe` setup package (`x86`, `x64`, `arm64`).
  * `msix-windows-installers`: Generates standalone `.msix` Framework packages for `x64`, `x86`, and `arm64`.
  * `wix-windows-installers`: Generates enterprise-ready `.msi` Windows Installer packages for `x64`, `x86`, and `arm64` using WiX Toolset v5.
* **Stage 4: Package Release (Fan-In):** Merges raw binaries with common assets, creates macOS Universal binaries via `lipo`, adds `install_symlinks.sh` for POSIX, and builds distribution `.zip` archives.
* **Stage 5: Cleanup Artifacts:** Safely deletes intermediate `raw-*`, `slice-*`, and common assets artifacts after all packaging and installer jobs complete.

---

## 2. Windows HybridCRT Architecture

### The `vcruntime140.dll` Problem
By default, compiling OpenSSL on Windows dynamically links to MSVC's runtime (`/MD`), introducing a hard runtime dependency on `vcruntime140.dll`. If end-users do not have the exact matching Microsoft Visual C++ Redistributable installed, applications crash.

### The HybridCRT Solution
Our build uses a custom OpenSSL target configuration file (**`Configurations/99-win-hybridcrt.conf`**) injected dynamically at build time:
1. **Compiler Flags (`cflags`):** Strips `/MD` and forces `/MT` (statically linking the Visual C++ runtime and STL routines into the library).
2. **Linker Flags (`lflags`):** Injects `/NODEFAULTLIB:libucrt.lib /DEFAULTLIB:ucrt.lib` (dynamically linking against Windows' native Universal CRT, `ucrtbase.dll`, which is pre-installed on all modern Windows installations).

### Target Matrix
| Target | Architecture | Linkage | Configuration Directives |
| :--- | :--- | :--- | :--- |
| `VC-WIN64A-SHARED` | x64 (AMD64) | Shared | `/MT /Zi`, `/NODEFAULTLIB:libucrt.lib /DEFAULTLIB:ucrt.lib` |
| `VC-WIN64A-STATIC` | x64 (AMD64) | Static | `disable => ["shared", "module"]`, `/MT /Zi` |
| `VC-WIN32-SHARED` | x86 (Win32) | Shared | `/MT /Zi`, `/NODEFAULTLIB:libucrt.lib /DEFAULTLIB:ucrt.lib` |
| `VC-WIN32-STATIC` | x86 (Win32) | Static | `disable => ["shared", "module"]`, `/MT /Zi` |

---

## 3. Windows ARM64X Dual-Architecture Pipeline

Windows on ARM supports **ARM64X** binaries—a single PE binary containing both **Native ARM64** code and **ARM64EC** (x64-compatible) code.

### The ARM64X Pipeline Design
1. **Parallel Compilation (`compile-windows-arm64x-slices`):**
   * Compiles **Native ARM64** (`VC-WIN64-ARM`) and **ARM64EC** (`VC-ARM64EC`) slices on separate runners.
   * Both slices are built with `multilib => "-arm64"` so their internal DLL references match (`libcrypto-3-arm64.dll` and `libssl-3-arm64.dll`).
   * Staged files preserve `.def`, `.res`, and all intermediate `.obj` trees for engines and providers.
2. **Linker Fusion (`merge-windows-arm64x`):**
   * **Static Libraries:** Uses `lib.exe /MACHINE:ARM64X` to merge the static `.lib` archives.
   * **Core DLLs:** Links `libcrypto-3-arm64.dll` and `libssl-3-arm64.dll` using `link.exe /DLL /MACHINE:ARM64X` with both `/DEF:` (for ARM64EC) and `/DEFARM64NATIVE:` (for Native ARM64) to generate dual-mode import thunks in `libcrypto.lib`.
   * **Dynamic Modules (Providers & Engines):** Isolates module-specific drivers, implementations, and context helpers, then links each module as an ARM64X DLL.
   * **Executable:** Copies the pure native ARM64 `openssl.exe`.
3. **Deep Verification:**
   * Validates that `openssl.exe` has the `AA64 machine (ARM64)` header.
   * Validates that every `.dll` has the `AA64 machine (ARM64)` header **and** contains the `Dynamic Value Relocation Table (DVRT)` in `loadconfig`.

---

## 4. macOS Universal (Unified) Binary Pipeline

To eliminate ecosystem fragmentation on macOS, our pipeline compiles separate Intel and Apple Silicon builds and fuses them into **Universal (Fat) Mach-O binaries** that work natively across all Macs.

### The 5 Steps of macOS Packaging:

#### A. Runner Selection (`macos-14`)
Packaging **MUST** execute on a `macos-14` (Apple Silicon M-series) runner so that Apple's native toolchain utilities (`lipo`, `otool`, `install_name_tool`, and Apple's Mach-O `strip`) execute natively without emulation.

#### B. Mach-O Header Rewriting & Relocatability (`install_name_tool`)
By default, OpenSSL bakes hardcoded absolute paths (e.g. `/usr/local/lib/libcrypto.3.dylib`) into the `LC_ID_DYLIB` and `LC_LOAD_DYLIB` load commands. Before merging, a bash loop inspects every binary with `otool -L` and rewrites the headers using `install_name_tool`:
* **Library ID:** Sets `LC_ID_DYLIB` to `@rpath/libname.dylib`.
* **Internal Dependencies:** Rewrites dependencies to `@loader_path/libname.dylib` (for core libraries) and `@loader_path/../libname.dylib` (for engines and providers).
* **Runtime Search Paths:** Adds `@executable_path` and `@loader_path` to `LC_RPATH`.

#### C. Symbol Stripping
* **Shared Libraries & Modules:** Stripped with `strip -x` (removes local/non-global debugging symbols while preserving public dynamic symbols).
* **Static Libraries:** Stripped with `strip -S` (removes debug symbols from `.a` archives).
* **CLI Executable:** Stripped with `strip`.

#### D. Universal Fusion (`lipo`)
The `lipo_file` helper function invokes `lipo -create -output <dest> <x64_file> <arm64_file>` to combine:
1. `openssl` CLI executable
2. Core shared libraries (`libcrypto.3.dylib`, `libssl.3.dylib`)
3. Dynamic engines and providers (`engines/*.dylib`, `providers/*.dylib`)
4. Static archives (`lib/static/libcrypto.a`, `lib/static/libssl.a`)

#### E. Symlink Management (`install_symlinks.sh`)
To ensure archive extraction safety on Windows filesystems, packages contain only physical versioned files (e.g., `libcrypto.3.dylib`). An `install_symlinks.sh` script is generated inside the package root so macOS/Linux developers can restore unversioned development symlinks (`libcrypto.dylib` -> `libcrypto.3.dylib`) with a single command.

---

## 5. Azure Trusted Signing (Artifact Signing) Setup

All Windows executables (`openssl.exe`), shared libraries (`*.dll`), engines, providers, InnoSetup installers (`.exe`), MSIX packages (`.msix`), and WiX installers (`.msi`) are digitally signed using **Microsoft Azure Trusted Signing** (formerly *Azure Code Signing* / *Artifact Signing*).

### Azure Infrastructure Prerequisites

#### 1. Artifact Signing Account & Certificate Profile
* An **Artifact Signing Account** created under resource provider `Microsoft.CodeSigning/codeSigningAccounts`.
* A **Certificate Profile** (e.g. Public Trust profile) created inside the account. The profile status must be **`Active`** and identity vetting must show **`Completed`**.

#### 2. Service Principal (App Registration)
* An App Registration created in Microsoft Entra ID (Azure AD).
* A **Client Secret** generated under **Certificates & secrets**.

#### 3. RBAC Role Assignments
The App Registration requires two role assignments:
1. **Subscription or Resource Group Scope:** Assign the **`Reader`** role so Azure CLI can discover the subscription context.
2. **Account or Certificate Profile Scope:** Assign the built-in role **`Artifact Signing Certificate Profile Signer`** (or `Code Signing Certificate Profile Signer`).

```bash
# Azure Cloud Shell command to assign the signing role:
az role assignment create \
  --assignee "<App-Registration-Client-ID>" \
  --role "Artifact Signing Certificate Profile Signer" \
  --scope "/subscriptions/<Subscription-ID>/resourceGroups/<Resource-Group>/providers/Microsoft.CodeSigning/codeSigningAccounts/<Account-Name>/certificateProfiles/<Profile-Name>"
```

### Signing Action Integration
In GitHub Actions workflows, signing is executed via `azure/artifact-signing-action@v2`:
* **Files Filter:** `exe,dll` (for raw binaries) or `exe`, `msix`, `msi` (for installers).
* **Timestamp Server:** `http://timestamp.acs.microsoft.com` (RFC 3161 SHA256).
* **Verification:** Validated on the runner using PowerShell's `Get-AuthenticodeSignature`.

---

## 6. Windows Installers (InnoSetup, MSIX & WiX MSI)

During release builds (`build_type == 'release'`), the workflow automatically builds, signs, and publishes three distinct Windows installer formats:

### A. InnoSetup Multi-Architecture Installer (`.exe`)
File pattern: `openssl-<version>-Windows-installer.exe`
* **Single Binary Setup:** Contains native binaries for `x64`, `x86`, and `arm64`.
* **Runtime Architecture Detection:** Automatically detects the host CPU and installs native binaries into `bin64` (on 64-bit OS) or `bin32` (on 32-bit OS).
* **32-bit Compatibility Option:** On 64-bit systems, users can select `[x] 32-bit (x86) Compatibility Runtime` to install 32-bit libraries into `bin32` alongside 64-bit libraries.
* **Standard Directory Layouts:**
  * **Per-Machine (Admin):** `C:\Program Files\TaurusTLS Developers\OpenSSL-<major.minor>\bin64\`
  * **Per-User (Non-Admin):** `%LocalAppData%\Programs\TaurusTLS Developers\OpenSSL-<major.minor>\bin64\`
* **OpenSSL Command Prompt:** Adds a Start Menu shortcut launching `cmd.exe` directly in the OpenSSL directory with local `PATH` configured.
* **License Display Page:** Renders `LICENSE.txt` during setup.

### B. MSIX Framework Packages (`.msix`)
File patterns: `openssl-<version>-Windows-<arch>.msix` (`x64`, `x86`, `arm64`)
* **Framework Package Architecture:** Declared with `<Framework>true</Framework>` to act as shared system libraries for other MSIX apps.
* **Isolated Deployment:** Deploys side-by-side into `C:\Program Files\WindowsApps\TaurusTLS.OpenSSL.<major.minor>_<version>_<arch>__<id>\`.
* **Package Dependency:** Consumed by other apps declaring `<PackageDependency Name="TaurusTLS.OpenSSL.3.0" ... />`.

### C. WiX Toolset MSI Packages (`.msi`)
File patterns: `openssl-<version>-Windows-<arch>.msi` (`x64`, `x86`, `arm64`)
* **Enterprise Deployment Standard:** Built with WiX Toolset v5 for Active Directory GPO, Microsoft Intune, and SCCM deployment.
* **Interactive Feature Selection Tree (`WixUI_FeatureTree`):**
  * 📦 **OpenSSL Native Runtime:** Installs native binaries to `%ProgramFiles%\TaurusTLS Developers\OpenSSL-<major.minor>\`.
    * └── 📦 **Add native directory to PATH:** Optional sub-feature allowing users to toggle system `PATH` registration.
  * 📦 **32-bit (x86) Compatibility Runtime (on x64 MSI):** Installs 32-bit binaries to `%ProgramFiles(x86)%\TaurusTLS Developers\OpenSSL-<major.minor>\`.
    * └── 📦 **Add 32-bit directory to PATH:** Optional sub-feature for 32-bit `PATH` registration.
* **Custom Directory Browsing:** Features include `ConfigurableDirectory="INSTALLFOLDER"` / `"INSTALLFOLDER32"`, enabling the `Browse...` button.
* **Deterministic Upgrade Codes:** Computes a deterministic `UpgradeCode` GUID based on `(Major.Minor, Architecture)`. Patches within the same minor release upgrade in-place via `<MajorUpgrade />`, while different minor versions coexist side-by-side.
* **Silent Execution:**
  ```cmd
  msiexec /i openssl-3.4.0-Windows-x64.msi /qn /norestart
  ```

---

## 7. Templates & Visual Branding Assets

Configuration templates and visual branding assets are maintained in repository directories rather than hardcoded in workflow files.

### Directory Structure
```text
.
├── assets/
│   ├── app.ico                        # Multi-size Windows icon (16x16, 32x32, 48x48, 256x256)
│   ├── WizardSmallImage.bmp           # 55x55 24-bit bitmap for InnoSetup top-right header
│   ├── openssl-150x150.png            # 150x150 PNG logo for MSIX manifest
│   ├── openssl-50x50.png              # 50x50 PNG logo for MSIX manifest
│   └── openssl-44x44.png              # 44x44 PNG logo for MSIX manifest
└── config/
    ├── AppxManifest.xml.template      # MSIX Framework package manifest template
    ├── openssl-installer.iss.template # InnoSetup script template
    └── openssl.wxs.template           # WiX MSI installer template
```

### Template Placeholders
Templates use `{{TOKEN}}` placeholders populated dynamically by PowerShell during the build:
* `{{VERSION}}`: Three-part version string (e.g. `3.4.0`).
* `{{MAJOR_MINOR}}`: Two-part version string for directory paths and upgrade tracks (e.g. `3.4`).
* `{{VERSION_FOUR_PART}}` / `{{MSIX_VERSION}}`: Padded four-part version string (e.g. `3.4.0.0`).
* `{{ARCH}}` / `{{MSIX_ARCH}}`: Architecture string (`x64`, `x86`, `arm64`).
* `{{APP_ID}}`: Deterministic InnoSetup application GUID per `Major.Minor`.
* `{{UPGRADE_CODE}}`: Deterministic WiX MSI upgrade GUID per `(Major.Minor, Arch)`.
* `{{PROGRAM_FILES_FOLDER}}`: Target Program Files root (`ProgramFiles64Folder` vs `ProgramFilesFolder`).
* `{{APP_PUBLISHER}}` / `{{PUBLISHER_DISPLAY_NAME}}`: Text branding name from Action Variables.
* `{{APP_PUBLISHER_URL}}`: Website / documentation URL from Action Variables.
* `{{MSIX_PUBLISHER}}`: Exact Subject DN string from `AZURE_MSIX_PUBLISHER` secret.
* `{{REDIST_DIR}}` / `{{OUTPUT_DIR}}` / `{{ASSETS_DIR}}`: Dynamic runner filesystem paths.

---

## 8. Repository Configuration: Secrets & Variables

### GitHub Repository Secrets
Configure in **Settings > Secrets and variables > Actions > Secrets**:

| Secret Name | Required | Description / Format | Example Value |
| :--- | :--- | :--- | :--- |
| `AZURE_CLIENT_ID` | Yes (Windows) | Application (Client) ID GUID of the Azure App Registration | `12345678-abcd-1234-abcd-1234567890ab` |
| `AZURE_CLIENT_SECRET` | Yes (Windows) | Client Secret password value from App Registration | `abc1Q~xxxxxx...` |
| `AZURE_TENANT_ID` | Yes (Windows) | Microsoft Entra Directory (Tenant) ID GUID | `87654321-dcba-4321-dcba-0987654321ba` |
| `AZURE_SUBSCRIPTION_ID` | Yes (Windows) | Azure Subscription ID GUID containing the signing account | `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee` |
| `AZURE_SIGNING_ACCOUNT_NAME` | Yes (Windows) | Exact name of the Artifact / Trusted Signing Account resource | `JPeterMugaas` |
| `AZURE_CERTIFICATE_PROFILE_NAME`| Yes (Windows) | Exact name of the Certificate Profile inside the Signing Account | `MyPublicProfile` |
| `AZURE_MSIX_PUBLISHER` | Yes (MSIX) | Exact Subject DN matching the code-signing certificate | `CN="TaurusTLS Developers", O=...` |
| `AZURE_CODESIGNING_ENDPOINT` | Optional | Regional endpoint URL (defaults to `eus` if omitted) | `https://eus.codesigning.azure.net/` |
| `RBPW_PAT` | Yes (Upstream) | Personal Access Token with `repo` and `workflow` scopes | `ghp_xxxxxxxxxxxx` |

> ⚠️ **Note on `RBPW_PAT`:** The upstream check workflow (`check-upstream.yml`) **must** use a Personal Access Token (`RBPW_PAT`) rather than the default `GITHUB_TOKEN` to trigger `build-openssl.yml`. Using `GITHUB_TOKEN` triggers GitHub's anti-recursion loop protection, which silently prevents `publish-release.yml` from firing afterward.

### GitHub Repository Variables
Configure in **Settings > Secrets and variables > Actions > Variables**:

| Variable Name | Required | Default Value (if unset) | Description |
| :--- | :--- | :--- | :--- |
| `PUBLISHER_DISPLAY_NAME` | Optional | `TaurusTLS Developers` | Friendly publisher text string displayed in installer UI |
| `PUBLISHER_URL` | Optional | `https://github.com/TaurusTLS-Developers/OpenSSL-Distribution` | Support / documentation URL in installer summary |

---

## 9. Release & Publishing Automation

The publishing workflow (`.github/workflows/publish-release.yml`) handles release publishing:

1. **Trigger:** Fires automatically on `workflow_run` completion of `Build OpenSSL` (or manually via `workflow_dispatch`).
2. **Safety Gate:** Automated runs on non-main branches or triggered via `workflow_run` force **Draft** release status for maintainer review.
3. **Artifact Harvesting:** Downloads all release packages matching `openssl-*` without decompressing.
4. **Publishing Scope:** Attaches all distribution formats to the GitHub Release via `gh release upload --clobber`:
   * Cross-platform `.zip` archives (`openssl-3.x-<OS>-<Arch>.zip`)
   * Multi-architecture Windows Setup installer (`openssl-3.x-Windows-installer.exe`)
   * Standalone MSIX Framework packages (`openssl-3.x-Windows-<arch>.msix`)
   * Enterprise WiX MSI installers (`openssl-3.x-Windows-<arch>.msi`)
5. **Maintainer Notification:** If a Draft release is created, the workflow automatically opens an issue tagging maintainers to review and publish the release.

---

## 10. Troubleshooting & Common Maintenance Scenarios

### 1. Azure Code Signing returns `403 (Forbidden)`
* **Cause 1: Role Assignment Missing:** Ensure the Service Principal has the **`Artifact Signing Certificate Profile Signer`** role assigned on the Signing Account or Certificate Profile scope.
* **Cause 2: Role Propagation Delay:** Azure RBAC assignments take 10–15 minutes to synchronize across Microsoft's signing endpoints. Wait 15 minutes after assigning roles before re-running.
* **Cause 3: Certificate Profile Inactive:** In Azure Portal, verify that the Certificate Profile status is **`Active`** and identity vetting is complete.

### 2. WiX build fails with `WIX0005: Unexpected child element 'Files'`
* **Cause:** The workflow is running WiX v4 instead of WiX v5.
* **Resolution:** Ensure the step installs WiX v5 via `dotnet tool install --global wix --version 5.0.2` and `wix extension add --global WixToolset.UI.wixext/5.0.2`.

### 3. WiX build fails with `WIX0230 / WIX0330` on Component GUIDs
* **Cause:** Non-file components (like `<Environment>`) cannot auto-generate GUIDs (`*`) without a file keypath.
* **Resolution:** Ensure non-file components in `openssl.wxs.template` specify explicit `Id`, `Guid`, and `<RegistryValue KeyPath="yes" />`.

### 4. InnoSetup compiler error: `Value of PrivilegesRequiredOverridesAllowed is invalid`
* **Cause:** InnoSetup list directives must be **space-separated**, not comma-separated.
* **Resolution:** Ensure `openssl-installer.iss.template` uses `PrivilegesRequiredOverridesAllowed=dialog commandline`.

### 5. OpenSSL 3.0.x / 3.1.x fails with `disables unknown feature docs`
* **Cause:** The `no-docs` configuration flag was only introduced in OpenSSL 3.2.0.
* **Resolution:** `build-openssl.yml` dynamically checks `INSTALL.md` for `no-docs` support before injecting `"docs"` into `99-win-hybridcrt.conf`.

### 6. macOS Universal packaging fails during `lipo`
* **Cause:** Missing binaries or architecture mismatch.
* **Resolution:** Ensure macOS packaging runs strictly on `macos-14` (Apple Silicon) runners so that `lipo`, `otool`, and `install_name_tool` execute natively.