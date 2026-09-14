# OpenSSL Distribution — Maintainer Guide & CI/CD Architecture

This document provides complete operational, architectural, and configuration documentation for maintaining the automated OpenSSL 3.x/4.x cross-platform compilation, code signing, packaging, installer generation, and release pipeline.

---

## Table of Contents
1. [CI/CD Architecture Overview](#1-cicd-architecture-overview)
2. [Script Library Organization & Conventions](#2-script-library-organization--conventions)
3. [Workflow Triggers & Kick-Start Workflows](#3-workflow-triggers--kick-start-workflows)
4. [Dynamic Matrix Generation & Target Filtering](#4-dynamic-matrix-generation--target-filtering)
5. [Windows Toolchain, HybridCRT & Parallel Compilation (`/Z7` + `jom`)](#5-windows-toolchain-hybridcrt--parallel-compilation-z7--jom)
6. [Windows ARM64X Dual-Architecture Pipeline](#6-windows-arm64x-dual-architecture-pipeline)
7. [Windows Installers Architecture (InnoSetup, MSIX, WiX v5)](#7-windows-installers-architecture-innosetup-msix-wix-v5)
8. [macOS Universal (Unified) Binary Pipeline](#8-macos-universal-unified-binary-pipeline)
9. [Azure Trusted Signing (Artifact Signing) Infrastructure](#9-azure-trusted-signing-artifact-signing-infrastructure)
10. [Template Management & Visual Assets (`config/` and `assets/`)](#10-template-management--visual-assets-config-and-assets)
11. [Local Execution & Incus in WSL2 Development Guide (`run-local.ps1`)](#11-local-execution--incus-in-wsl2-development-guide-run-localps1)
12. [Repository Secrets & Variables Reference](#12-repository-secrets--variables-reference)
13. [Release & Publishing Automation (`publish-release.yml`)](#13-release--publishing-automation-publish-releaseyml)
14. [Troubleshooting Guide & Common Pitfalls](#14-troubleshooting-guide--common-pitfalls)

---

## 1. CI/CD Architecture Overview

The build pipeline (`.github/workflows/build-openssl.yml`) adheres to an **Orchestrator + Script Library Pattern** using a 5-stage **Fan-Out / Fan-In** model:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 0. Validate Inputs & Dynamic Matrix (validate-version)                      │
│    - Evaluates inputs, EOL status, generates dynamic compile/package matrix │
│    - Uploads build-metadata (version.txt) universally                       │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. Build Common Assets (build-common-assets)                                │
│    - C Headers (include/), HTML Docs (doc/), README.txt, LICENSE.txt/.rtf   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. Compile Binaries (Fan-Out: Win x64/x86, Linux, macOS, Android, iOS)      │
│    2b. Compile Windows ARM64X Slices (Native ARM64 + ARM64EC parallel runs) │
│    2c. Merge & Sign ARM64X (Fuse static/import libs & link ARM64X DLLs)     │
└──────────────┬───────────────────────┼───────────────────────┬──────────────┘
               │                       │                       │
               ▼                       ▼                       ▼
┌───────────────────────────┐ ┌─────────────────────────┐ ┌───────────────────┐
│ 3a. InnoSetup Installer   │ │ 3b. MSIX Frameworks    │ │ 4. Package Release│
│ Multi-Arch EXE Setup      │ │ x64, x86, ARM64 MSIX   │ │ Fan-In ZIPs + lipo│
├───────────────────────────┤ ├─────────────────────────┤ └────────┬──────────┘
│ 3c. WiX Toolset v5 MSI    │ │ (Release Builds Only)   │          │
│ x64, x86, ARM64 MSI       │ │                         │          │
└──────────────┬────────────┘ └────────┬────────────────┘          │
               │                       │                           │
               └───────────────────────┼───────────────────────────┘
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 5. Cleanup Intermediate Artifacts (Deletes raw-*, slice-*, common-assets-*) │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Script Library Organization & Conventions

To ensure zero copy-pasting and allow any script to be executed locally on a developer workstation, all step business logic is extracted out of the YAML workflow into standalone scripts under `scripts/`.

### Directory Layout
```text
scripts/
├── 00_validate_version/
│   └── 01_check_eol.sh            # EOL check, version validation, dynamic matrix generation
├── 01_build_common_assets/
│   ├── 01_build_assets.sh         # Headers, HTML docs, README.txt
│   └── 02_generate_license_rtf.ps1# Plain-text to Segoe UI RTF license generator
├── 02_compile_binaries/
│   ├── 01_validate_secrets.ps1    # Azure signing credentials pre-check
│   ├── 02_prepare_win_targets.sh  # Copies 99-win-hybridcrt.conf & detects no-docs
│   ├── 03_compile_windows.cmd     # MSVC + jom /Z7 parallel build for x64/x86
│   ├── 04_check_binaries.ps1      # Scans dist folder for binaries to sign
│   ├── 05_verify_signatures.ps1   # Validates Authenticode signatures on DLLs/EXEs
│   ├── 06_install_linux_deps.sh   # Installs libsctp-dev and aarch64 cross-toolchains
│   ├── 07_compile_posix.sh        # Compiles Linux, macOS, Android, and iOS
│   └── 08_organize_posix.sh       # Strips symbols, separates libs, creates install_symlinks.sh
├── 03_compile_arm64x_slices/
│   ├── 01_prepare_slice_targets.sh# Copies 99-win-hybridcrt.conf for slice targets
│   └── 02_compile_slice.cmd       # Compiles Native ARM64 or ARM64EC slices
├── 04_merge_arm64x/
│   ├── 01_fuse_binaries.ps1       # Fuses static libs, links ARM64X DLLs & dynamic modules
│   ├── 02_check_binaries.ps1      # Scans merged folder for binaries to sign
│   └── 03_verify_signatures.ps1   # Validates Authenticode signatures on ARM64X DLLs
├── 05_innosetup_installer/
│   ├── 01_validate_secrets.ps1    # Azure credentials check
│   ├── 02_stage_redist.ps1        # Stages multi-arch redistributables
│   ├── 03_build_installer.ps1     # InnoSetup script generation & ISCC compilation
│   └── 04_verify_signatures.ps1   # Validates installer Authenticode signature
├── 06_msix_installers/
│   ├── 01_validate_secrets.ps1    # Azure credentials check
│   ├── 02_build_package.ps1       # Generates AppxManifest & packs MSIX per architecture
│   └── 03_verify_signatures.ps1   # Validates MSIX Authenticode signatures
├── 07_wix_installers/
│   ├── 01_validate_secrets.ps1    # Azure credentials check
│   ├── 02_stage_redist.ps1        # Stages multi-arch redistributables
│   ├── 03_build_msi.ps1           # Populates openssl.wxs & builds MSI via WiX v5
│   └── 04_verify_signatures.ps1   # Validates MSI Authenticode signatures
├── 08_package_release/
│   ├── 01_merge_binaries.sh       # Merges raw artifacts into dist/
│   ├── 02_build_macos_universal.sh# Rewrites Mach-O headers and fuses slices via lipo
│   └── 03_finalize_package.sh     # Bundles common assets, version stamp, and creates .zip
├── 09_cleanup_artifacts/
│   └── 01_delete_artifacts.sh     # Deletes intermediate raw-*, slice-*, and common assets
└── common/
    ├── check_binaries.ps1         # Reusable binary discovery
    ├── stage_windows_redist.ps1   # Reusable multi-arch redistributable staging
    ├── validate_azure_secrets.ps1 # Reusable Azure credentials validation
    └── verify_signatures.ps1      # Reusable Authenticode signature verification
```

### Script Execution Contract
1. **Zero Path Arithmetic:** Scripts do not crawl parent trees via relative paths (`../../..`). They receive absolute paths or environment variables (`$env:COMMON_SCRIPTS_DIR`, `$env:GITHUB_WORKSPACE`, etc.).
2. **Fail-Fast & Zero Fallbacks:** Scripts strictly enforce `set -euo pipefail` (Bash), `$ErrorActionPreference = 'Stop'` (PowerShell), and explicit `if errorlevel 1 exit /b %errorlevel%` (CMD). No silent fallback copying is permitted.
3. **Dual Execution Support:** GitHub Actions uses scripts as-is; We works on local pipeline implementation that will use scripts via `run-local.ps1`. This approach will help to use the same pipeline logic for both local and GitHub Actions execution.

---

## 3. Workflow Triggers & Kick-Start Workflows

The repository provides two workflow entry points:

### 1. `build-openssl-release.yml` ("Build OpenSSL Release")
* **Primary interface for official releases.**
* **Input:** A single input: `version` (e.g. `3.4.0`).
* **Strict Validation:** Strictly validates `Major.Minor.Patch` numeric syntax (`^[0-9]+\.[0-9]+\.[0-9]+$`). Pre-releases (e.g. `4.1.0-alpha1`) and branches are rejected upfront to prevent Windows installer failures.
* **Automatic Execution:** Automatically calls `build-openssl.yml` with all platforms, code signing (`sign_binaries: true`), and all Windows installers (`build_installers: true`) enabled.

### 2. `build-openssl.yml` ("Build OpenSSL")
* **Core orchestrator and development interface.**
* Provides fine-grained checkboxes in the UI:
  * `sign_binaries`: Boolean (default: `false`).
  * `build_installers`: Boolean (default: `false`).
  * `build_windows`: Boolean (default: `true`).
  * `build_linux`: Boolean (default: `true`).
  * `build_macos`: Boolean (default: `true`).
  * `build_android`: Boolean (default: `true`).
  * `build_ios`: Boolean (default: `true`).
  * `ignore_eol`: Boolean (default: `false`).
  * `keep_raw_artifacts`: Boolean (default: `false`).

---

## 4. Dynamic Matrix Generation & Target Filtering

To prevent unselected platforms from spinning up runners, `validate-version` dynamically compiles JSON matrix arrays for `compile-binaries` and `package-release`:

1. **Filtering in `01_check_eol.sh`:** Inspects incoming boolean inputs (`BUILD_WINDOWS`, `BUILD_LINUX`, etc.) and filters a comprehensive platform catalog using `jq`.
2. **Dynamic Ingestion:**
   ```yaml
   strategy:
     matrix:
       include: ${{ fromJSON(needs.validate-version.outputs.compile_matrix) }}
   ```
3. **Zero Runner Overhead:** If a maintainer unchecks all platforms except `iOS`, GitHub Actions **only provisions the 2 iOS runners**. Zero Windows, Linux, or Android VMs are queued or launched.
4. **Universal Metadata:** `validate-version` unconditionally generates `version.txt` and uploads `build-metadata`. This guarantees that partial or single-platform builds (e.g., Windows only) can be published without missing metadata errors.

---

## 5. Windows Toolchain, HybridCRT & Parallel Compilation (`/Z7` + `jom`)

### The HybridCRT Architecture
To eliminate the runtime dependency on `vcruntime140.dll`, all Windows builds use **`config/99-win-hybridcrt.conf`**:
* **`/MT`:** Statically links the Visual C++ runtime and standard library.
* **`/NODEFAULTLIB:libucrt.lib /DEFAULTLIB:ucrt.lib`:** Dynamically links against Windows' native Universal CRT (`ucrtbase.dll`).

### Parallel Multi-Core Builds (`/Z7` + `jom`)
By default, OpenSSL on Windows builds sequentially using single-threaded `nmake`.
1. **The PDB Contention Issue:** Using `/Zi` forces multiple parallel compiler instances to write to a shared `.pdb` file simultaneously, causing fatal file lock errors.
2. **The `/Z7` Solution:** Custom configurations inject `/Z7` (which embeds debug symbol records directly into `.obj` files). This eliminates lock contention.
3. **Multi-Threaded Execution:** Compilation steps install and invoke **`jom`** across all CPU cores:
   ```cmd
   jom -j "%NUMBER_OF_PROCESSORS%"
   ```
4. **Build Time Reduction:** Cuts Windows compilation times from ~15 minutes down to ~5–6 minutes per target.
5. **Static Compatibility:** Scripts automatically create a dummy `ossl_static.pdb` file to satisfy legacy OpenSSL 3.0.x `copy.pl` installation rules during static builds.

---

## 6. Windows ARM64X Dual-Architecture Pipeline

Windows on ARM uses **ARM64X** binaries—a single PE binary containing both **Native ARM64** code and **ARM64EC** (x64-compatible) code.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. Compile Slices in Parallel (compile-windows-arm64x-slices)               │
│    - Slice A (Native ARM64): VC-WIN64-ARM (multilib => "-arm64", /Z7)       │
│    - Slice B (ARM64EC):      VC-ARM64EC   (multilib => "-arm64", /Z7)       │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. Fuse ARM64X Binaries (merge-windows-arm64x)                              │
│    - Merge Static Archives: lib.exe /MACHINE:ARM64X libcrypto.lib/libssl.lib│
│    - Link Core DLLs: link.exe /MACHINE:ARM64X with /DEF and /DEFARM64NATIVE │
│    - Link Dynamic Modules: providers (legacy.dll) and engines (capi.dll)    │
│    - Copy Native CLI: openssl.exe (Pure Native AA64 ARM64)                  │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. Deep Verification (dumpbin /headers & /loadconfig)                       │
│    - Asserts AA64 machine (ARM64) header                                    │
│    - Asserts Dynamic Value Relocation Table (DVRT) presence                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Module Linking Rules:
* **Core Libraries (`libcrypto`, `libssl`):** Linked with both `/DEF:` (for ARM64EC) and `/DEFARM64NATIVE:` (for Native ARM64). `libssl` links against static crypto archives to resolve internal helper symbols (`WPACKET_*`).
* **Providers (`legacy.dll`):** Fused by combining `providers\legacy-dso-*.obj`, `providers\liblegacy.lib`, and `providers\libcommon.lib` with `libcrypto.lib`. Objects from `default` or `base` providers are strictly excluded.
* **Engines (`capi.dll`, `padlock.dll`, `loader_attic.dll`):** Linked by combining all engine-specific objects (`*-dso-*.obj`, including `crypto\pem\loader_attic-dso-pvkfmt.obj`) with `libcrypto.lib`.
* **Clean Layout:** All `.exp`, `.64n.exp`, `.def`, `.rsp`, and `.lib` files are purged from `dist\engines\` and `dist\providers\`.

---

## 7. Windows Installers Architecture (InnoSetup, MSIX, WiX v5)

All Windows installers are built strictly for official release builds (`build_type == 'release'`).

### A. InnoSetup Multi-Architecture Installer (`.exe`)
* **File Name:** `openssl-<version>-Windows-installer.exe`
* **Architecture Routing:**
  * Native x64 installed to `bin64` (per-machine: `C:\Program Files\TaurusTLS Developers\OpenSSL-<Major.Minor>\bin64\`).
  * Native ARM64EC installed to `bin64`.
  * Native x86 installed to `bin32` (per-machine: `C:\Program Files (x86)\TaurusTLS Developers\OpenSSL-<Major.Minor>\bin32\`).
  * Optional `[x] 32-bit (x86) Compatibility Runtime` installs x86 binaries into `bin32` on 64-bit systems.
* **Privileges:** `PrivilegesRequired=lowest`, `PrivilegesRequiredOverridesAllowed=dialog commandline`, `UsePreviousPrivileges=no` (ensures the install-mode dialog always prompts by default).
* **Shortcuts:** Adds an "OpenSSL Command Prompt" shortcut launching `cmd.exe /K` with `PATH` pre-loaded.
* **Upgrades:** Upgrades in-place within the same `Major.Minor` series via deterministic UUIDv5 `AppId`.

### B. MSIX Framework Packages (`.msix`)
* **File Names:** `openssl-<version>-Windows-x64.msix`, `openssl-<version>-Windows-x86.msix`, `openssl-<version>-Windows-arm64.msix`
* **Framework Architecture:** Configured with `<Framework>true</Framework>` (no `<Applications>` or `<Capabilities>`).
* **Isolation:** Deploys side-by-side in `C:\Program Files\WindowsApps\` with architecture isolation.
* **Dependency Declaration:** Consuming MSIX apps reference the framework via `<PackageDependency>`.

### C. WiX Toolset v5 MSI Installers (`.msi`)
* **File Names:** `openssl-<version>-Windows-x64.msi`, `openssl-<version>-Windows-x86.msi`, `openssl-<version>-Windows-arm64.msi`
* **Feature Tree UI (`WixUI_FeatureTree`):**
  * `OpenSSL Native Runtime`: Installs native binaries. Configurable path via `ConfigurableDirectory="INSTALLFOLDER"`.
  * `Add native directory to PATH`: Sub-feature (can be unchecked).
  * `32-bit (x86) Compatibility Runtime`: Optional sub-feature on x64 MSI. Configurable path via `ConfigurableDirectory="INSTALLFOLDER32"`.
* **License Formatting:** Displays `LICENSE.rtf` with Segoe UI font and wrapped paragraphs.
* **Upgrades:** Upgrades in-place within the same `Major.Minor` track via deterministic `UpgradeCode`.

---

## 8. macOS Universal (Unified) Binary Pipeline

File: `openssl-<version>-macOS-universal.zip`

1. **Compilation (`compile-binaries`):** Compiles `darwin64-x86_64-cc` (Intel) and `darwin64-arm64-cc` (Apple Silicon) slices.
2. **Packaging Runner:** Runs natively on `macos-14` (Apple Silicon).
3. **Relocatability (`install_name_tool`):**
   * Sets `LC_ID_DYLIB` to `@rpath/libname.dylib`.
   * Rewrites internal dependencies to `@loader_path/` (or `@loader_path/../` for modules).
   * Adds `@executable_path` and `@loader_path` to `LC_RPATH`.
4. **Symbol Stripping:** `strip -x` on dynamic libraries, `strip -S` on static `.a` archives, `strip` on the CLI executable.
5. **Universal Fusion (`lipo`):** Uses `lipo -create` to merge executables, shared libraries, dynamic modules, and static archives.
6. **Symlink Script:** Embeds `install_symlinks.sh` for developer symlink restoration.

---

## 9. Azure Trusted Signing (Artifact Signing) Infrastructure

All Windows binaries (`.exe`, `.dll`), installers (`.exe`, `.msi`), and packages (`.msix`) are signed with **Microsoft Azure Trusted Signing**.

### Azure RBAC Setup Commands:
```bash
# 1. Assign Reader role on Subscription / Resource Group:
az role assignment create \
  --assignee "<App-Registration-Client-ID>" \
  --role "Reader" \
  --scope "/subscriptions/<Subscription-ID>/resourceGroups/<Resource-Group>"

# 2. Assign Signing role on Certificate Profile scope:
az role assignment create \
  --assignee "<App-Registration-Client-ID>" \
  --role "Artifact Signing Certificate Profile Signer" \
  --scope "/subscriptions/<Subscription-ID>/resourceGroups/<Resource-Group>/providers/Microsoft.CodeSigning/codeSigningAccounts/<Account-Name>/certificateProfiles/<Profile-Name>"
```

### Verification:
```powershell
Get-AuthenticodeSignature .\openssl.exe
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-installer.exe
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-x64.msix
Get-AuthenticodeSignature .\openssl-3.4.0-Windows-x64.msi
```

---

## 10. Template Management & Visual Assets (`config/` and `assets/`)

### Directory Layout
```text
config/
├── 99-win-hybridcrt.conf        # Unified HybridCRT & ARM64X target configs
├── AppxManifest.xml.template    # MSIX Framework package template
├── openssl-installer.iss.template # InnoSetup script template
├── openssl.wxs.template         # WiX Toolset v5 template
├── README.txt                   # Static distribution README
├── install_symlinks_linux.sh.template # Linux symlink restorer
└── install_symlinks_macos.sh.template # macOS symlink restorer

assets/
├── app.ico                      # Multi-size Windows icon (16x16 to 256x256)
├── WizardSmallImage.bmp         # InnoSetup 55x55 24-bit header bitmap
├── openssl-150x150.png          # MSIX 150x150 logo
├── openssl-50x50.png            # MSIX 50x50 logo
└── openssl-44x44.png            # MSIX 44x44 logo
```

---

## 11. Local Execution & Incus in WSL2 Development Guide (`run-local.ps1`)

Developers can execute and debug any pipeline step locally on a workstation without triggering GitHub Actions.

### A. Initial Setup: Linux Build Container in WSL2 (Incus)
Incus system containers run full Linux operating systems inside WSL2 with zero Docker overhead:

```bash
# Inside WSL2:
incus launch images:ubuntu/24.04 openssl-builder
incus exec openssl-builder -- apt-get update
incus exec openssl-builder -- apt-get install -y build-essential libsctp-dev gcc-aarch64-linux-gnu libc6-dev-arm64-cross perl

# Mount your local repository directory into the container:
incus config device add openssl-builder workspace disk source=/mnt/c/Projects/OpenSSL-Distribution path=/workspace
```

### B. Using `run-local.ps1`
The local runner script sets up `.runner/github_output.txt` and `.runner/github_env.txt` and manages environment variables:

```powershell
# Run a single script locally:
.\run-local.ps1 -Script "scripts/01_build_common_assets/02_generate_license_rtf.ps1"

# Run an entire job locally:
.\run-local.ps1 -Job "04_merge_arm64x"

# Run a compile step for a specific target:
.\run-local.ps1 -Job "02_compile_binaries" -Platform "Windows" -Arch "x64" -Linkage "shared"
```

---

## 12. Repository Secrets & Variables Reference

### GitHub Repository Secrets
Configure in **Settings > Secrets and variables > Actions > Secrets**:

| Secret Name | Required | Description / Format | Example Value |
| :--- | :--- | :--- | :--- |
| `AZURE_CLIENT_ID` | Yes (Windows Signing) | Application (Client) ID GUID of Azure App Registration | `12345678-abcd-1234-abcd-1234567890ab` |
| `AZURE_CLIENT_SECRET` | Yes (Windows Signing) | Client Secret password value from App Registration | `abc1Q~xxxxxx...` |
| `AZURE_TENANT_ID` | Yes (Windows Signing) | Microsoft Entra Directory (Tenant) ID GUID | `87654321-dcba-4321-dcba-0987654321ba` |
| `AZURE_SUBSCRIPTION_ID` | Yes (Windows Signing) | Azure Subscription ID GUID containing signing account | `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee` |
| `AZURE_SIGNING_ACCOUNT_NAME` | Yes (Windows Signing) | Exact name of Artifact / Trusted Signing Account | `JPeterMugaas` |
| `AZURE_CERTIFICATE_PROFILE_NAME`| Yes (Windows Signing)| Exact name of Certificate Profile inside Account | `MyPublicProfile` |
| `AZURE_MSIX_PUBLISHER` | Yes (MSIX Signing) | Exact Subject DN matching code-signing certificate | `CN="TaurusTLS Developers", O=...` |
| `AZURE_CODESIGNING_ENDPOINT` | Optional | Regional endpoint URL (defaults to `eus` if omitted) | `https://eus.codesigning.azure.net/` |
| `RBPW_PAT` | Yes (Upstream Automation) | Personal Access Token with `repo` and `workflow` scopes | `ghp_xxxxxxxxxxxx` |

### GitHub Repository Variables
Configure in **Settings > Secrets and variables > Actions > Variables**:

| Variable Name | Required | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `PUBLISHER_DISPLAY_NAME` | Optional | `TaurusTLS Developers` | Text branding string displayed in installer UI |
| `PUBLISHER_URL` | Optional | `https://github.com/TaurusTLS-Developers/OpenSSL-Distribution` | Support / documentation URL in installer summary |

---

## 13. Release & Publishing Automation (`publish-release.yml`)

The publishing workflow executes automatically when `Build OpenSSL` or `Build OpenSSL Release` completes:

1. **Trigger:** Listens to `workflows: ["Build OpenSSL", "Build OpenSSL Release"]`.
2. **Metadata Handoff:** Reads `version.txt` from the `build-metadata` artifact uploaded universally by Stage 0.
3. **Draft Safety:** Automated runs default to **Draft** status for human verification.
4. **Publishing Scope:** Collects all files matching `*.zip`, `*.exe`, `*.msix`, and `*.msi` and uploads them via `gh release upload --clobber`.
5. **Maintainer Notification:** Automatically creates a GitHub issue notifying maintainers to review and publish the release.

---

## 14. Troubleshooting Guide & Common Pitfalls

### 1. Azure Code Signing returns `403 (Forbidden)`
* **Root Cause 1 — Missing Role Assignment:** Ensure the App Registration (Service Principal) has been granted the built-in role **`Artifact Signing Certificate Profile Signer`** (or `Code Signing Certificate Profile Signer`) on the Certificate Profile or Signing Account scope.
* **Root Cause 2 — Propagation Delay:** Azure RBAC assignments take 10 to 15 minutes (and sometimes up to 30 minutes) to replicate across Microsoft's global signing endpoints (`*.codesigning.azure.net`). Wait 15 minutes after assigning the role before triggering a workflow run.
* **Root Cause 3 — Inactive Certificate Profile:** In the Azure Portal, open your Signing Account and verify that the Certificate Profile status is strictly **`Active`** and that identity vetting shows **`Completed`**.

---

### 2. MakeAppx validation error (`0x80080204`)
* **Root Cause 1 — Capabilities in Framework:** In Windows AppX/MSIX specifications, Framework packages (`<Framework>true</Framework>`) cannot contain `<Capabilities>` or `<Applications>`. Ensure your `config/AppxManifest.xml.template` excludes both elements entirely.
* **Root Cause 2 — Publisher Subject Mismatch:** The `Publisher` attribute in `AppxManifest.xml` must match the exact Subject Distinguished Name (DN) string on your code signing certificate character-for-character (e.g. `CN="TaurusTLS Developers", O=...`).
* **Root Cause 3 — Missing Image Assets:** If `<Logo>` points to an asset that was not copied into the staging folder (e.g. `assets\openssl-150x150.png`), `MakeAppx.exe` fails with `The file name ... declared for element ... doesn't exist in the package`. Ensure the staging step copies the entire `assets/` directory.

---

### 3. OpenSSL 3.0.x / 3.1.x fails with `disables unknown feature docs`
* **Root Cause:** The `no-docs` configuration flag was introduced in OpenSSL 3.2.0. Passing `no-docs` or specifying `"docs"` in the `disable` array on older OpenSSL branches causes the configuration engine to abort with `unknown feature docs`.
* **Resolution:** Scripts `02_prepare_win_targets.sh` and `01_prepare_slice_targets.sh` dynamically grep `INSTALL.md` for `no-docs`. If absent, the script strips `"__DOCS__"` from `99-win-hybridcrt.conf` automatically before compilation starts.

---

### 4. Windows static builds fail with `Can't Open ossl_static.pdb`
* **Root Cause:** Compiling with multi-threaded `/Z7` embeds symbols into `.obj` files and skips creating `ossl_static.pdb`. In OpenSSL 3.0 through 3.3, `windows-makefile.tmpl` has a hardcoded rule calling `copy.pl ossl_static.pdb` during static `install_sw`.
* **Resolution:** Script `03_compile_windows.cmd` writes a dummy fallback file (`if not exist ossl_static.pdb echo dummy > ossl_static.pdb`) before running `nmake install_sw`, satisfying the legacy copy rule cleanly.

---

### 5. `WPACKET_put_bytes__` or internal symbol `LNK2001` during ARM64X linking
* **Root Cause:** In OpenSSL, `WPACKET_*` and other internal helper routines are private library functions not exported in `libcrypto.def`. Passing only the import library `libcrypto.lib` to `link.exe` when linking `libssl-3-arm64.dll` causes unresolved external symbol errors.
* **Resolution:** Script `04_merge_arm64x/01_fuse_binaries.ps1` feeds both the import library (`import\libcrypto.lib`) and the static archives (`static\libcrypto.lib`) into the `libssl` link command so internal helper symbols resolve without error.

---

### 6. Provider linking fails with `LNK2005: already defined in libdefault`
* **Root Cause:** OpenSSL compiles the provider framework (`providers/common/`) multiple times with different flags (`libdefault-lib-*.obj`, `liblegacy-lib-*.obj`, etc.). Passing loose wildcard patterns (`*.obj`) into `legacy.dll` mixes default provider objects with legacy provider objects.
* **Resolution:** `04_merge_arm64x/01_fuse_binaries.ps1` selectively links only module-specific driver objects (`legacyprov.obj`) and the compiled static helper libraries (`liblegacy.lib` and `libcommon.lib`), strictly excluding `libdefault-*.obj`.

---

### 7. macOS Universal packaging fails during `lipo`
* **Root Cause 1 — Runner Architecture:** macOS packaging must run natively on `macos-14` (Apple Silicon M-series) so that `lipo`, `otool`, and `install_name_tool` execute without emulation bottlenecks.
* **Root Cause 2 — Hardcoded Paths:** OpenSSL bakes absolute paths into `LC_ID_DYLIB`. Script `08_package_release/02_build_macos_universal.sh` runs `install_name_tool` to rewrite IDs to `@rpath` and internal dependencies to `@loader_path` before fusing slices with `lipo`.

---

### 8. `publish-release.yml` fails on partial or Windows-only builds
* **Root Cause:** Legacy pipelines uploaded `build-metadata` (`version.txt`) only during `package-release (Linux x64)`. If Linux was unchecked in the UI, metadata was missing and the publish job crashed.
* **Resolution:** `build-metadata` generation is decoupled and executed universally by Stage 0 (`validate-version`). `publish-release.yml` downloads the universal metadata artifact and uses dynamic file discovery (`find artifacts -type f ...`) to publish whatever assets were built without failing on unselected platforms.