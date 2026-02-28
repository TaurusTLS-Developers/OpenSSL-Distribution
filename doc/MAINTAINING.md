# Maintainer Guide

This repository uses a fully automated CI/CD pipeline to build, package, and release OpenSSL binaries across multiple platforms (Windows, Linux, macOS, Android, iOS).

## ⚙️ Architecture

The pipeline consists of three primary workflows:

1.  **Check Upstream (`check-upstream.yml`):**
    *   Runs on a **Schedule** (Daily).
    *   **Smart Polling:** Uses the `endoflife.date/api/openssl.json` API via `jq` to dynamically fetch active `3.x` branches.
    *   Automatically skips any versions where the End-Of-Life (EOL) date has passed.
    *   If a new, actively supported version is found that doesn't exist in our Releases, it triggers the **Build** workflow.

2.  **Build (`build-openssl.yml`):**
    *   Can be triggered manually or by the Poller.
    *   **Build Gatekeeper:** Validates the requested version against the `endoflife.date` API before running matrix jobs. It aborts builds for dead versions unless the `ignore_eol` manual input is explicitly checked.
    *   **Cross-Version Compatibility:** Uses fallback mechanisms for static build flags (`no-apps`, `no-module`) to support both LTS (3.0/3.1) and newer (3.2+) branches.
    *   **Packaging:** Generates a **Single Unified Package** (`.zip`) per platform containing shared libs, static libs, headers, and docs. 
    *   **Clean Archives:** Strips all debug symbols. Never includes symlinks in the archive to prevent Windows extraction failures (provides an `install_symlinks.sh` script for POSIX users instead).
    *   Uploads raw `.zip` archives using `actions/upload-artifact@v7` (`archive: false`) to prevent double-zipping by GitHub, alongside a `build-metadata` artifact containing the exact version string.

3.  **Publish (`publish-release.yml`):**
    *   Triggered automatically when a **Build** completes successfully, or can be run manually.
    *   Downloads the raw `.zip` artifacts perfectly intact using `actions/download-artifact@v8` (`skip-decompress: true`).
    *   Reads the OpenSSL version deterministically from the `build-metadata` artifact.
    *   Uses the GitHub CLI (`gh release`) to safely create or update the release and upload the artifacts (`--clobber`).
    *   **Drafts & Notifications:** Automatic runs force a **Draft** status. When a draft is created, the workflow automatically opens a **GitHub Issue** (`gh issue create`) to notify maintainers that a new release is ready for human review and publishing.
    *   If triggered automatically from a non-default branch, it appends the branch name to the release tag (e.g., `v3.4.0-build-update`) for safe testing.

## 🛠️ Manual Operations

### How to build a specific version manually
1.  Go to **Actions** tab -> **Build OpenSSL 3.x**.
2.  Click **Run workflow**.
3.  Enter the version (e.g., `3.4.0`).
4.  *(Optional)* Check **Ignore EOL Check** if you specifically need to build an older, unsupported version (e.g., `3.0.0`).
5.  The pipeline will build the artifacts and automatically trigger the Publish workflow as a Draft.

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