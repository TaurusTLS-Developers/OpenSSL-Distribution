# Maintainer Guide

This repository uses a fully automated CI/CD pipeline to build and release OpenSSL binaries.

## ⚙️ Architecture

The pipeline consists of three workflows:

1.  **Check Upstream (`check-upstream.yml`):**
    *   Runs on a **Schedule** (Daily).
    *   Polls the official OpenSSL repository for new tags (e.g., `openssl-3.4.0`).
    *   If a new version is found that doesn't exist in our Releases, it triggers the **Build** workflow.

2.  **Build (`build-openssl.yml`):**
    *   Can be triggered manually or by the Poller.
    *   Compiles OpenSSL for all target platforms in parallel.
    *   Generates a **Single Unified Package** (`.zip`) per platform containing shared libs, static libs, headers, and docs.
    *   Uses a dedicated `build-metadata` artifact to pass the exact version string to the publishing workflow deterministically.
    *   Uploads raw `.zip` archives using `actions/upload-artifact@v7` (`archive: false`) to prevent double-zipping by GitHub.

3.  **Publish (`publish-release.yml`):**
    *   Triggered automatically when a **Build** completes successfully, or can be run manually.
    *   Downloads the raw `.zip` artifacts using `actions/download-artifact@v8` (`skip-decompress: true`).
    *   Reads the OpenSSL version from the `build-metadata` artifact.
    *   Uses the GitHub CLI (`gh release`) to safely create or update the release and upload the artifacts (`--clobber`).
    *   If triggered automatically from a non-default branch, it appends the branch name to the release tag (e.g., `v3.4.0-build-update`) for easy testing.

## 🛠️ Manual Operations

### How to build a specific version manually
1.  Go to **Actions** tab -> **Build OpenSSL 3.x**.
2.  Click **Run workflow**.
3.  Enter the version (e.g., `3.4.0`).
4.  The pipeline will build the artifacts.

### How to publish a release manually
If an automatic publish fails, or you want to publish a specific build run:
1.  Go to **Actions** tab -> **Publish Release**.
2.  Click **Run workflow**.
3.  Provide the **Build Workflow Run ID** (found in the URL of the successful build run).
4.  Optionally provide a custom tag name and toggle the Draft status.

### How to backfill multiple missing versions
1.  Go to **Actions** tab -> **Bulk Build Missing Releases**.
2.  Click **Run workflow**.
3.  This script compares local releases against upstream and triggers builds for the latest patch of every minor version (e.g., 3.0.x, 3.3.x) that is missing.

### Secrets Configuration
To allow the workflows to trigger each other, a **Personal Access Token (PAT)** is required.
*   **Secret Name:** `RBPW_PAT`
*   **Required Scopes:** `repo` (or specific `actions:write`, `contents:write`).
*   **Note:** The default `GITHUB_TOKEN` cannot trigger recursive workflows.