# OpenSSL Distribution for Ossl4Pas

This repository houses the **Automated Build Pipeline** for creating cross-platform OpenSSL 3.x binaries used by the [Ossl4Pas](https://github.com/tregubovav-dev/Ossl4Pas) framework.

It automatically compiles, tests, and packages OpenSSL for Windows, Linux, macOS, Android, and iOS.

> **⚠️ DEPRECATION NOTICE**
> The static folders (`binaries/Windows`, `binaries/Android`, etc.) in this repository are **deprecated**.
> Please download the latest compiled binaries from the [**Releases**](https://github.com/TaurusTLS-Developers/OpenSSL-Distribution/releases) page.

---

## 🚀 Build Pipeline Architecture

This repository uses GitHub Actions to orchestrate a 3-stage pipeline:

### 1. Polling (Schedule)
*   **Workflow:** `Check Upstream OpenSSL`
*   **Frequency:** Runs daily.
*   **Action:** Checks the official OpenSSL repository for new tags (e.g., `3.3.1`). If a new version is found that hasn't been released here, it triggers the Build workflow.

### 2. Building (Matrix)
*   **Workflow:** `Build OpenSSL 3.x`
*   **Action:** Compiles the source code in parallel across 5 platforms:
    *   **Windows:** x86, x64, ARM64 (Static CRT `/MT`)
    *   **Linux:** x64, ARM64
    *   **macOS:** x64 (Intel), ARM64 (Apple Silicon)
    *   **Android:** ARM, ARM64, x86, x64
    *   **iOS:** ARM64 (Static libraries only)
*   **Artifacts:** Produces ZIP/TAR.GZ archives containing the binaries.

### 3. Releasing
*   **Workflow:** `Publish Release`
*   **Trigger:** Runs automatically when a Build completes successfully.
*   **Action:**
    1.  Verifies the binaries (Smoke Test).
    2.  Creates a **Draft Release**.
    3.  Uploads the artifacts.

---

## 📦 Artifacts Structure

We provide two types of packages for every platform:

### 1. Runtime Package (`openssl-3.x.x-{platform}.zip`)
Contains the minimal files required to **run** an application.
*   **Root:** Contains shared libraries (`.dll`, `.so`, `.dylib`) and the `openssl` executable.
*   **Providers/Engines:** Contains `legacy`, `default`, etc.
*   **Symbols:** Stripped (small size).

### 2. SDK / Dev Package (`openssl-3.x.x-{platform}-dev.zip`)
Contains everything required to **compile** or debug applications.
*   `bin/`: Shared libraries and Executable.
*   `lib/`: Static libraries (`.lib`, `.a`).
*   `include/`: C header files.
*   `debug/`: Debug symbols (`.pdb`, `.dSYM`, or unstripped `.so`).
*   `doc/`: HTML documentation.

---

## 🛠️ How to Trigger Manually

### Build a Specific Version
If you need to rebuild a specific version (e.g., 3.2.0) manually:

1.  Go to **Actions** -> **Build OpenSSL 3.x**.
2.  Click **Run workflow**.
3.  Enter the version: `3.2.0`.
4.  Click **Run**.

### Bulk Build (Backfill)
To build *all* missing minor versions (e.g., latest 3.0.x, 3.1.x, 3.2.x) that are not yet in Releases:

1.  Go to **Actions** -> **Bulk Build Missing Releases**.
2.  Click **Run workflow**.
3.  (Optional) Check `Dry Run` to see what would be triggered.

---

## ⚙️ Setup Requirements (For Maintainers)

To enable the automated chain, the repository requires a **Personal Access Token (PAT)**.

1.  Create a PAT with `repo` and `workflow` scopes.
2.  Add it to **Settings -> Secrets and variables -> Actions**.
3.  Name: `PAT_TOKEN`.

*This is required because the default `GITHUB_TOKEN` cannot trigger subsequent workflows recursively.*
