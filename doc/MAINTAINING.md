# Maintainer Guide

This repository uses a fully automated CI/CD pipeline to build, package, and release OpenSSL binaries across multiple platforms (Windows, Linux, macOS, Android, iOS).

## ⚙️ Architecture

The pipeline consists of three primary workflows:

1.  **Check Upstream (`check-upstream.yml`):**
    *   Runs daily via cron.
    *   Uses the `endoflife.date` API to fetch active 3.x branches.
    *   Triggers the Build workflow via `gh workflow run` using a Personal Access Token (`RBPW_PAT`) to allow workflow chaining.
    *   Explicitly passes `build_type="release"` to ensure correct mode selection.

2.  **Build (`build-openssl.yml`):**
    *   **Validate Mode & Version:** Handles two build modes:
        *   `release`: Uses official tags (e.g., `openssl-3.4.0`) and performs EOL checks.
        *   `branch`: Clones a specific git branch (e.g., `master`, `openssl-3.0`) and verifies its existence.
    *   **Build Common Assets:** Compiles architecture-independent headers and HTML docs once.
        *   Generates a centralized `README.txt`.
        *   Extracts `LICENSE.txt` from the source root.
        *   Removes unnecessary large directories to keep the "common assets" artifact lean.
    *   **Compile Binaries (Fan-Out):** A highly parallel matrix that splits builds by OS, Architecture, AND Linkage (`shared` vs `static`). Uses parallelized `make -j$(nproc)` for speed.
    *   **Package Release (Fan-In):** Downloads assets and raw binaries.
        *   *Adaptive Merging:* Handles inconsistent `actions/download-artifact` behavior by detecting both nested and flattened artifact structures.
        *   *macOS:* Combines x64 and arm64 into Universal binaries using `lipo` and `install_name_tool`.
        *   *Naming:* Releases use standard version naming; Branch builds use `<branch>_<timestamp>` (e.g., `master_20260314T150000Z`).
        *   *Metadata:* Generates `version.txt`. If in `branch` mode, prepends `branch: ` to the content.
    *   **Cleanup:** Deletes intermediate artifacts via GitHub API unless `keep_raw_artifacts` is true.

3.  **Publish (`publish-release.yml`):**
    *   Triggered automatically when a Build completes.
    *   Creates a Draft release and opens a GitHub Issue for maintainer review.

## 🛠️ Manual Operations

### How to build manually
1.  Go to **Actions** tab -> **Build OpenSSL 3.x**.
2.  Click **Run workflow**.
3.  **Build Type:** Select `release` for official tags or `branch` for moving git branches.
4.  **OpenSSL Version or Branch:** Enter the tag (e.g., `3.4.0`) or branch name (e.g., `openssl-3.6`).
5.  *(Optional)* Check **Ignore EOL Check** if you need to build an unsupported release.
6.  *(Optional)* Check **Keep raw build artifacts** for debugging.

### How to publish a release manually
If an automatic publish fails:
1.  Go to **Actions** tab -> **Publish Release**.
2.  Click **Run workflow**.
3.  Provide the **Build Workflow Run ID** (found in the URL of the successful build run).
4.  Toggle **Create as Draft** as needed.

### Reviewing and Publishing Drafts
1. Check the **Issues** tab for a "👀 Review Required" notification.
2. Click the link to view the Draft Release.
3. Verify the artifacts and release notes.
4. Click **Edit**, uncheck "Set as a draft", and click **Publish release**.
5. Close the notification issue.

### Secrets Configuration
*   **Secret Name:** `RBPW_PAT`
*   **Required Scopes:** `repo`, `actions:write`.
*   **Note:** Required for workflow chaining (`check-upstream` -> `build-openssl`). Standard operations use the default `GITHUB_TOKEN`.
