# OpenSSL Distribution — Maintainer Guide & CI/CD Architecture

This document provides complete operational, architectural, and configuration documentation for maintaining the automated OpenSSL 3.x cross-platform compilation, code signing, packaging, and release pipeline.

---

## Table of Contents
1. [Pipeline Overview & Architecture](#1-pipeline-overview--architecture)
2. [Windows Toolchain & HybridCRT Architecture](#2-windows-toolchain--hybridcrt-architecture)
3. [Azure Trusted Signing (Artifact Signing) Setup](#3-azure-trusted-signing-artifact-signing-setup)
4. [Windows Installers (InnoSetup & MSIX Frameworks)](#4-windows-installers-innosetup--msix-frameworks)
5. [Templates & Visual Branding Assets](#5-templates--visual-branding-assets)
6. [Repository Configuration: Secrets & Variables](#6-repository-configuration-secrets--variables)
7. [Release & Publishing Automation](#7-release--publishing-automation)
8. [Troubleshooting & Common Maintenance Scenarios](#8-troubleshooting--common-maintenance-scenarios)

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
│ 1. Build Common Assets (Headers, HTML Docs, License, README)                │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. Compile Binaries (Fan-Out Matrix across 11 targets + HybridCRT + Signing)│
└──────────────┬───────────────────────┼───────────────────────┬──────────────┘
               │                       │                       │
               ▼                       ▼                       ▼
┌───────────────────────────┐ ┌─────────────────────────┐ ┌───────────────────┐
│ 3a. InnoSetup Installer   │ │ 3b. MSIX Frameworks    │ │ 4. Package Release│
│ Multi-Arch EXE Installer  │ │ x64, x86, ARM64EC MSIX │ │ Fan-In ZIPs + lipo│
└──────────────┬────────────┘ └────────┬────────────────┘ └────────┬──────────┘
               │                       │                           │
               └───────────────────────┼───────────────────────────┘
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 5. Cleanup Intermediate Artifacts (gh api -X DELETE raw-* artifacts)        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Stage Summary
* **Stage 0: Validate Version:** Validates version against OpenSSL releases or Git branch/tag SHAs. Verifies EOL date via `endoflife.date` API.
* **Stage 1: Build Common Assets:** Compiles C headers (`include/`) and HTML documentation (`doc/`) once on a fast Linux runner.
* **Stage 2: Compile Binaries (Fan-Out):** Compiles raw shared and static libraries across Windows (`x64`, `x86`, `arm64ec`), Linux (`x64`, `arm64`), macOS (`x64`, `arm64`), Android (`arm64`, `arm`), and iOS (`arm64`, `sim-arm64`). Windows binaries are digitally signed with Azure Trusted Signing.
* **Stage 3: Windows Installers (Release Builds Only):**
  * `InnoSetup-windows-installer`: Generates a single multi-architecture `.exe` setup package (`x86`, `x64`, `arm64ec`).
  * `msix-windows-installers`: Generates standalone `.msix` Framework packages for `x64`, `x86`, and `arm64ec`.
* **Stage 4: Package Release (Fan-In):** Merges raw binaries with common assets, creates macOS Universal binaries via `lipo`, adds `install_symlinks.sh` for POSIX, and builds clean distribution `.zip` archives.
* **Stage 5: Cleanup Artifacts:** Safely deletes intermediate `raw-*` and common assets artifacts after all packaging and installer jobs have completed.

---

## 2. Windows Toolchain & HybridCRT Architecture

### The `vcruntime140.dll` Problem
By default, compiling OpenSSL on Windows dynamically links to MSVC's runtime (`/MD`), which introduces a hard runtime dependency on `vcruntime140.dll`. If end-users do not have the exact matching Microsoft Visual C++ Redistributable package installed on their systems, applications crash with missing DLL errors.

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
| `VC-ARM64EC-SHARED` | ARM64EC | Shared | `/arm64EC /O1 /Zi /wd4267 /wd4244`, `ARFLAGS="/nologo /MACHINE:ARM64EC"`, `LDFLAGS="/debug /MACHINE:ARM64EC"` |
| `VC-ARM64EC-STATIC` | ARM64EC | Static | `disable => ["shared", "module", "asm"]`, `/arm64EC /O1 /Zi` |

---

## 3. Azure Trusted Signing (Artifact Signing) Setup

All Windows executables (`openssl.exe`), shared libraries (`*.dll`), engines, providers, InnoSetup installers (`.exe`), and MSIX packages (`.msix`) are digitally signed using **Microsoft Azure Trusted Signing** (formerly *Azure Code Signing* / *Artifact Signing*).

### Azure Infrastructure Prerequisites

#### 1. Artifact Signing Account & Certificate Profile
* A **Trusted Signing Account** (or *Artifact Signing Account*) created under resource provider `Microsoft.CodeSigning/codeSigningAccounts`.
* A **Certificate Profile** (e.g. Public Trust profile) created inside the account. The profile status must be **`Active`** and identity vetting must show **`Completed`**.

#### 2. Service Principal (App Registration)
* An App Registration created in Microsoft Entra ID (Azure AD).
* A **Client Secret** created under **Certificates & secrets**.

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
* **Files Filter:** `exe,dll` (for raw binaries) or `exe` / `msix` (for installers).
* **Timestamp Server:** `http://timestamp.acs.microsoft.com` (RFC 3161 SHA256).
* **Verification:** Validated on the runner using PowerShell's `Get-AuthenticodeSignature`.

---

## 4. Windows Installers (InnoSetup & MSIX Frameworks)

During release builds (`build_type == 'release'`), the workflow automatically builds, signs, and publishes two complementary Windows installer formats:

### A. InnoSetup Multi-Architecture Installer (`.exe`)
A single, unified setup executable (**`openssl-<version>-Windows-installer.exe`**) capable of installing on all Windows platforms:
* **Runtime Architecture Detection:**
  * **64-bit Intel/AMD Windows (x64):** Installs native x64 binaries.
  * **64-bit ARM64 Windows (Surface/Snapdragon):** Installs native ARM64EC binaries.
  * **32-bit Windows (x86):** Installs native 32-bit binaries.
* **32-bit Compatibility Option:** On 64-bit systems, users can check `[x] 32-bit (x86) Compatibility Runtime` to install 32-bit libraries alongside 64-bit libraries without file collision.
* **Directory Layout (Windows Compliant):**
  * **Per-Machine (Admin / All Users):**
    * 64-bit: `C:\Program Files\TaurusTLS Developers\OpenSSL-<ver>\`
    * 32-bit: `C:\Program Files (x86)\TaurusTLS Developers\OpenSSL-<ver>\`
  * **Per-User (Current User / Non-Admin):**
    * 64-bit: `%LocalAppData%\Programs\TaurusTLS Developers\OpenSSL-<ver>\x64\`
    * 32-bit: `%LocalAppData%\Programs\TaurusTLS Developers\OpenSSL-<ver>\x86\`
* **Developer Terminal Shortcut:** The Start Menu shortcut opens a dedicated Command Prompt session in the installation directory with the active binary path pre-loaded in local `PATH`.

### B. MSIX Framework Packages (`.msix`)
Published as standalone architecture Framework packages (**`openssl-<version>-Windows-<arch>.msix`** for `x64`, `x86`, `arm64ec`):
* Declared with `<Framework>true</Framework>` to act as shared system libraries for other MSIX apps.
* Windows MSIX architecture guarantees complete directory isolation under `C:\Program Files\WindowsApps\TaurusTLS.OpenSSL_<version>_<arch>__<publisherid>\`.

---

## 5. Templates & Visual Branding Assets

Configuration templates and visual branding assets are maintained in repository directories rather than hardcoded in workflow files.

### Directory Structure
~~~text
.
├── assets/
│   ├── app.ico                    # Multi-size Windows icon (16x16, 32x32, 48x48, 256x256)
│   ├── WizardSmallImage.bmp       # 55x55 24-bit bitmap for InnoSetup top-right header
│   ├── openssl-150x150.png        # 150x150 PNG logo for MSIX manifest
│   ├── openssl-50x50.png          # 50x50 PNG logo for MSIX manifest
│   └── openssl-44x44.png          # 44x44 PNG logo for MSIX manifest
└── config/
    ├── AppxManifest.xml.template  # MSIX Framework package manifest template
    └── openssl-installer.iss.template # InnoSetup script template
~~~

### Template Placeholders
Templates use simple `{{TOKEN}}` placeholders that are dynamically populated by PowerShell during the build:
* `{{VERSION}}`: Three-part version string (e.g. `3.4.0`).
* `{{MSIX_VERSION}}`: Padded four-part version string (e.g. `3.4.0.0`).
* `{{ARCH}}` / `{{MSIX_ARCH}}`: Architecture string (`x64`, `x86`, `arm64ec` / `arm64`).
* `{{APP_PUBLISHER}}` / `{{PUBLISHER_DISPLAY_NAME}}`: Text branding name from Action Variables.
* `{{APP_PUBLISHER_URL}}`: Website / documentation URL from Action Variables.
* `{{MSIX_PUBLISHER}}`: Exact Subject DN string from `AZURE_MSIX_PUBLISHER` secret.
* `{{REDIST_DIR}}` / `{{OUTPUT_DIR}}` / `{{ASSETS_DIR}}`: Dynamic runner filesystem paths.

---

## 6. Repository Configuration: Secrets & Variables

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

## 7. Release & Publishing Automation

The publishing workflow (`.github/workflows/publish-release.yml`) handles release publishing:

1. **Trigger:** Fires automatically on `workflow_run` completion of `Build OpenSSL` (or manually via `workflow_dispatch`).
2. **Safety Gate:** Automated runs on non-main branches or triggered via `workflow_run` force **Draft** release status for maintainer review.
3. **Artifact Harvesting:** Downloads all release packages matching `openssl-*` without decompressing.
4. **Publishing Scope:** Attaches all three distribution formats to the GitHub Release via `gh release upload --clobber`:
   * Cross-platform `.zip` archives (`openssl-3.x-<OS>-<Arch>.zip`)
   * Multi-architecture Windows Setup installer (`openssl-3.x-Windows-installer.exe`)
   * Standalone MSIX Framework packages (`openssl-3.x-Windows-<arch>.msix`)
5. **Maintainer Notification:** If a Draft release is created, the workflow automatically opens an issue tagging maintainers to review and publish the release.

---

## 8. Troubleshooting & Common Maintenance Scenarios

### 1. Azure Code Signing returns `403 (Forbidden)`
* **Cause 1: Role Assignment Missing:** Ensure the Service Principal has the **`Artifact Signing Certificate Profile Signer`** role assigned on the Signing Account or Certificate Profile scope.
* **Cause 2: Role Propagation Delay:** Azure RBAC assignments take 10–15 minutes to synchronize across Microsoft's signing endpoints. Wait 15 minutes after assigning roles before re-running.
* **Cause 3: Certificate Profile Inactive:** In Azure Portal, verify that the Certificate Profile status is **`Active`** and identity vetting is complete.

### 2. MakeAppx validation error (`0x80080204`)
* **Cause 1: Invalid Attribute:** Ensure `AppxManifest.xml` uses `MaxVersionTested="10.0.22621.0"` (never `MaxVersion`).
* **Cause 2: Capabilities in Framework Package:** Framework packages (`<Framework>true</Framework>`) cannot declare `<Capabilities>` or `<Applications>`.
* **Cause 3: Publisher Mismatch:** The `Publisher` attribute in `AppxManifest.xml` must match the certificate's Subject string exactly.

### 3. OpenSSL 3.0.x / 3.1.x fails with `disables unknown feature docs`
* **Cause:** The `no-docs` configuration flag was only introduced in OpenSSL 3.2.0.
* **Resolution:** `build-openssl.yml` dynamically checks `INSTALL.md` for `no-docs` support before injecting `"docs"` into `99-win-hybridcrt.conf`.

### 4. macOS Universal packaging fails during `lipo`
* **Cause:** Missing binaries or architecture mismatch.
* **Resolution:** Ensure macOS packaging runs strictly on `macos-14` (Apple Silicon) runners so that `lipo`, `otool`, and `install_name_tool` execute natively.
~~~