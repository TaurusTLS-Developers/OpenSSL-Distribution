# Maintainer Guide

This repository uses a fully automated CI/CD pipeline to build and release OpenSSL binaries.

## ⚙️ Architecture

The pipeline consists of three workflows:

1.  **Check Upstream (`check-upstream.yml`):**
    *   Runs on a **Schedule** (Daily).
    *   Polls the official OpenSSL repository for new tags (e.g., `openssl-3.3.1`).
    *   If a new version is found that doesn't exist in our Releases, it triggers the **Build** workflow.

2.  **Build (`build-openssl.yml`):**
    *   Can be triggered manually or by the Poller.
    *   Compiles OpenSSL for all target platforms in parallel.
    *   Generates artifacts and uploads them to the GitHub Action run.

3.  **Publish (`publish-release.yml`):**
    *   Triggered automatically when a **Build** completes successfully.
    *   Downloads the artifacts.
    *   Performs a "Smoke Test" (executing `openssl version`) on Windows, Linux, and macOS to verify integrity.
    *   Creates a **Draft Release** with the tag format `v.{version}` (e.g., `v.3.3.1`).

## 🛠️ Manual Operations

### How to build a specific version manually
1.  Go to **Actions** tab -> **Build OpenSSL 3.x**.
2.  Click **Run workflow**.
3.  Enter the version (e.g., `3.3.0`).
4.  The pipeline will build and create a Draft Release automatically.

### How to backfill multiple missing versions
1.  Go to **Actions** tab -> **Bulk Build Missing Releases**.
2.  Click **Run workflow**.
3.  This script compares local releases against upstream and triggers builds for the latest patch of every minor version (e.g., 3.0.x, 3.3.x) that is missing.

### Secrets Configuration
To allow the workflows to trigger each other, a **Personal Access Token (PAT)** is required.
*   **Secret Name:** `RBPW_PAT`
*   **Required Scopes:** `repo` (or specific `actions:write`, `contents:write`).
*   **Note:** The default `GITHUB_TOKEN` cannot trigger recursive workflows.
