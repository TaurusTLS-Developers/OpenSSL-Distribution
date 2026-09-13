# 📋 Master Refactoring Plan & Implementation Checklist

This master plan defines the transition of the OpenSSL CI/CD pipeline from a monolithic workflow to an **Orchestrator + Script Library Architecture**, complete with local execution support via **Incus in WSL** and a local runner emulator.

---

## 🏛️ 1. Target Directory & Script Naming Specification

All execution scripts will be organized into numbered job directories with clean, 2-digit numbered scripts:

~~~text
scripts/
├── 00_validate_version/
│   └── 01_check_eol.sh
├── 01_build_common_assets/
│   ├── 01_build_assets.sh
│   └── 02_convert_license_rtf.ps1
├── 02_compile_binaries/
│   ├── 01_prepare_win_targets.sh
│   ├── 02_compile_windows.cmd
│   ├── 03_install_linux_deps.sh
│   ├── 04_compile_posix.sh
│   └── 05_organize_posix.sh
├── 03_compile_arm64x_slices/
│   ├── 01_prepare_slice_targets.sh
│   └── 02_compile_slice.cmd
├── 04_merge_arm64x/
│   ├── 01_fuse_binaries.ps1
│   └── 02_verify_arm64x.ps1
├── 05_innosetup_installer/
│   ├── 01_stage_redist.ps1
│   └── 02_build_installer.ps1
├── 06_msix_installers/
│   ├── 01_stage_redist.ps1
│   └── 02_build_package.ps1
├── 07_wix_installers/
│   ├── 01_stage_redist.ps1
│   └── 02_build_msi.ps1
├── 08_package_release/
│   ├── 01_merge_binaries.sh
│   ├── 02_build_macos_universal.sh
│   └── 03_finalize_package.sh
├── 09_cleanup_artifacts/
│   └── 01_delete_artifacts.sh
├── common/
│   ├── helpers_msvc.ps1           # Dynamic vswhere.exe & vcvarsall.bat resolver
│   ├── helpers_signing.ps1        # Azure Trusted Signing login & verification
│   └── helpers_env.ps1 / .sh      # Local GITHUB_OUTPUT / GITHUB_ENV emulation
├── config/                        # Template configurations (.template)
├── assets/                        # Icons, logos, and bitmaps
├── run-local.ps1                  # Local Workflow Runner Emulator (PowerShell)
└── migrate-scripts.ps1            # Local Migration Script (Auto-renaming & relocation)
~~~

---

## 🔄 2. Migration Automation Tool (`scripts/migrate-scripts.ps1`)

To safely migrate from the current flat script names (e.g. `2c_merge-windows-arm64x_3_fuse.ps1`) to the new structured directory hierarchy without manual file editing, we will create a dedicated migration script.

* **Functionality:**
  * Creates all target directories (`scripts/00_...` through `scripts/09_...`).
  * Relocates and renames files to their clean 2-digit names.
  * Validates that all required scripts exist post-migration.
  * Works cleanly on local Windows/Linux/macOS developer machines.

---

## 🖥️ 3. Linux Build Environment (`incus` inside WSL)

To build and test Linux / POSIX targets on local Windows machines without installing cross-compilers on the host OS:

* **Backend Engine:** `incus` system container manager running inside WSL2 (e.g. `Ubuntu-24.04`).
* **Persistent Dependency Cache:** `libsctp-dev`, `gcc-aarch64-linux-gnu`, `build-essential`, and `perl` installed once inside a dedicated `openssl-builder` container instance.
* **Workspace Sharing:** Host workspace folder mounted directly into the container (`/workspace`).
* **Execution Model:** `run-local.ps1` invokes Linux build steps via:
  ~~~powershell
  wsl -d <Distro> -- incus exec openssl-builder -- bash /workspace/scripts/02_compile_binaries/04_compile_posix.sh
  ~~~

---

## 🚀 4. Local Runner Emulator (`run-local.ps1`) & State Management

A PowerShell CLI harness that reproduces GitHub Actions job execution locally:

### Key Capabilities:
1. **Isolated State Directory (`.runner/`):**
   * Sets `$env:GITHUB_WORKSPACE = "$PWD"`
   * Sets `$env:GITHUB_OUTPUT = "$PWD/.runner/github_output.txt"`
   * Sets `$env:GITHUB_ENV = "$PWD/.runner/github_env.txt"`
   * Automatically parses outputs from `$GITHUB_OUTPUT` to pass parameters dynamically between sequential steps.
2. **Selective Execution:**
   * Run an entire job: `./run-local.ps1 -Job 04_merge_arm64x`
   * Run a specific step: `./run-local.ps1 -Job 02_compile_binaries -Step 02_compile_windows`
   * Target specific platform/linkage: `./run-local.ps1 -Job 02_compile_binaries -Platform Windows -Arch x64 -Linkage shared`
3. **Mock Artifact Handoff:**
   * Reads from local folders (`./slices`, `./raw_artifact`, `./installers`) so you can test downstream jobs independently without running upstream compilations.

---

## ⚙️ 5. Workflow Dispatch & Call Input Enhancements

Update `.github/workflows/build-openssl.yml` with the following input schema:

### Workflow Input Toggles:
* **`version`:** Target OpenSSL release or branch (default: `3.4.0`).
* **`build_type`:** `release` or `branch` (default: `release`).
* **`platforms`:** `all`, `windows`, `linux`, `macos`, `android`, `ios` (default: `all`).
* **`sign_binaries`:** Boolean toggle to enable/disable Azure Trusted Signing (default: `false` — off by default).
* **`build_installers`:** Boolean toggle to enable/disable InnoSetup, MSIX, and WiX installers (default: `false` — off by default).
* **`ignore_eol`:** Boolean toggle for EOL check override (default: `false`).
* **`keep_raw_artifacts`:** Boolean toggle to skip intermediate artifact deletion (default: `false`).

---

# 📋 Master Tracking Checklist

### Phase 0: Decompose solid workflow into set of scripts and convert workflow to the orchestrator style
- [x] **0.1** Decompose solid workflow into set of scripts.
- [x] **0.2** Convert workflow to the orchestrator style.

### Phase 1: Migration & Repository Reorganization
- [x] **1.1** Implement `scripts/migrate-scripts.ps1` / `restructure-scripts.sh` to automate file relocation and renaming.
- [x] **1.2** Execute migration script and create the 2-digit numbered folder structure (`scripts/00_...` to `09_...`).
- [x] **1.3** Verify that all templates (`config/`) and assets (`assets/`) are cleanly organized.

### Phase 2: State Emulation & Common Helper Library
- [x] **2.1** Implement local state manager (`.runner/github_output.txt` & `.runner/github_env.txt`).
- [x] **2.2** Update all Bash scripts to safely support local `$GITHUB_OUTPUT` / `$GITHUB_ENV` fallbacks.
- [x] **2.3** Standardize dynamic Visual Studio path resolution (`vswhere.exe` + `vcvarsall.bat`).
- [x] **2.4** Standardize common Azure Signing and verification helpers (`scripts/common/`).

### Phase 3: Local Runner Emulator (`run-local.ps1`)
- [x] **3.1** Implement `run-local.ps1` core CLI parser and step dispatcher.
- [ ] **3.2** Configure `incus` / WSL2 container backend execution hooks for Linux targets.
- [ ] **3.3** Implement local mock artifact folder handoff logic.
- [ ] **3.4** Validate local execution of individual steps on developer workstation.

### Phase 4: Workflow Orchestrator Integration (`build-openssl.yml`)
- [ ] **4.1** Define boolean UI checkbox inputs (`sign_binaries`, `build_installers`, `build_windows`, `build_linux`, `build_macos`, `build_android`, `build_ios`) for `workflow_dispatch` and `workflow_call`.
- [ ] **4.2** Decouple `build-metadata` (`version.txt`) from `package-release (Linux x64)` and move it to `validate-version` (guarantees release metadata exists even for Windows-only or single-platform builds).
- [ ] **4.3** Add conditional gates for signing steps (`inputs.sign_binaries == true`).
- [ ] **4.4** Add conditional gates for installer jobs (`inputs.build_installers == true && inputs.build_windows == true`).
- [ ] **4.5** Add platform matrix filter gates across `compile-binaries`, `compile-windows-arm64x-slices`, and `package-release`.
- [ ] **4.6** Implement preset kick-start workflow (`build-for-release.yml`) with single `version` input.
- [ ] **4.7** Update `check-upstream.yml` to dispatch builds with all targets, signing, and installers enabled.
- [ ] **4.8** Verify `publish-release.yml` resilience against partial builds.

### Phase 5: Documentation & Validation
- [ ] **5.1** Update `MAINTAINING.md` and `README.md` with complete architecture details.
- [ ] **5.2** Execute final end-to-end release dry-run on development branch.
---