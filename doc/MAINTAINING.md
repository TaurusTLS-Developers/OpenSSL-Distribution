# Maintainer Guide

This repository uses a fully automated CI/CD pipeline to build, package, and release OpenSSL binaries across multiple platforms (Windows, Linux, macOS, Android, iOS).

## ⚙️ Architecture

The pipeline consists of three primary workflows:

1.  **Check Upstream (`check-upstream.yml`):**
    *   Runs daily via cron.
    *   Uses the `endoflife.date` API to fetch active 3.x branches.
    *   Triggers the Build workflow via `gh workflow run` using a Personal Access Token (`RBPW_PAT`) to allow workflow chaining.

2.  **Build (`build-openssl.yml`):**
    *   **Validate Version:** Checks EOL status. Aborts if EOL unless `ignore_eol` is true.
    *   **Build Common Assets:** Compiles architecture-independent headers and HTML docs once on a Linux runner.
    *   **Compile Binaries (Fan-Out):** A highly parallel matrix that splits builds by OS, Architecture, AND Linkage (`shared` vs `static`). Uploads raw, unstripped binaries as temporary artifacts.
    *   **Package Release (Fan-In):** Downloads common assets and raw binaries.
        *   *macOS:* Combines x64 and arm64 into Universal binaries using `lipo` and `install_name_tool`.
        *   *Windows/Linux/Android/iOS:* Organizes files into a strict directory layout.
        *   Strips debug symbols, drops PDBs, and generates `install_symlinks.sh` (POSIX only) and `README.txt`.
        *   Uploads the final `.zip` without double-zipping (`archive: false`).
    *   **Cleanup:** Automatically deletes intermediate `raw-*` and common assets artifacts via GitHub API to save storage space, unless `keep_raw_artifacts` is true.

3.  **Publish (`publish-release.yml`):**
    *   Triggered automatically when a Build completes.
    *   Downloads the raw `.zip` artifacts intact.
    *   Reads the version from the `build-metadata` artifact.
    *   Creates a Draft release and opens a GitHub Issue for maintainer review.

## 🛠️ Manual Operations

### How to build a specific version manually
1.  Go to **Actions** tab -> **Build OpenSSL 3.x**.
2.  Click **Run workflow**.
3.  Enter the version (e.g., `3.4.0`).
4.  *(Optional)* Check **Ignore EOL Check** if you specifically need to build an older, unsupported version (e.g., `3.0.0`).
5.  *(Optional)* Check  **Keep raw build artifacts** if you need to keep compiled artifacts, for example for debug purposes.
6.  The pipeline will build the artifacts and automatically trigger the Publish workflow as a Draft.

### How to publish a release manually
If an automatic publish fails, or you want to publish a specific build run manually:
1.  Go to **Actions** tab -> **Publish Release**.
2.  Click **Run workflow**.
3.  Provide the **Build Workflow Run ID** (found in the URL of the successful build run, e.g., `1234567890`).
4.  Toggle the **Create as Draft** status as needed.

### Reviewing and Publishing Drafts
When the CI pipeline automatically builds a new upstream release, it creates a Draft release and opens a GitHub Issue.
1. Check the **Issues** tab for a "👀 Review Required" notification.
2. Click the link in the issue to view the Draft Release.
3. Verify the release notes and attached `.zip` artifacts.
4. Click **Edit**, uncheck "Set as a draft", and click **Publish release**.
5. Close the notification issue.

### Secrets Configuration
To allow the workflows to trigger each other (e.g., `check-upstream` triggering `build-openssl`), a **Personal Access Token (PAT)** is required.
*   **Secret Name:** `RBPW_PAT`
*   **Required Scopes:** `repo` (or specific `actions:write`, `contents:write`).
*   **Note:** The default `GITHUB_TOKEN` cannot trigger recursive workflows. (However, `publish-release.yml` uses the standard `GITHUB_TOKEN` to create releases and issues).