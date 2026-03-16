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
    *   **Validate Mode & Version:** Handles three build scenarios:
        *   `release`: Uses official tags (e.g., `3.4.0`) and performs EOL checks.
        *   `branch`: Clones an official branch (e.g., `master`, `openssl-3.1`).
        *   `fork`: Clones a public fork using the `user/repo/branch` format.
    *   **Deterministic Builds:** The validator resolves all inputs to a specific **Commit SHA** at the start of the run. All subsequent jobs (Compile, Package) use this SHA to ensure "point-in-time" consistency.
    *   **Human-Readable UI:** The workflow dynamically updates the GitHub Run Name to a slugified `user_repo_branch` scheme (e.g., `Build OpenSSL slontis_openssl_fix-logic`) for better visibility.
    *   **Build Common Assets:** Compiles architecture-independent headers and HTML docs once.
    *   **Compile Binaries (Fan-Out):** A highly parallel matrix that splits builds by OS, Architecture, AND Linkage.
    *   **Package Release (Fan-In):** 
        *   *Slugified Naming:* Filenames and internal metadata use a standardized `user_repo_branch` scheme where all `/` are replaced by `_`.
        *   *Release Gatekeeping:* If a build is detected as a **Fork**, the workflow intentionally withholds the `build-metadata` artifact. This acts as a "hard stop" that prevents the Publish workflow from creating an official release from untrusted code.
    *   **Cleanup:** Deletes intermediate artifacts unless `keep_raw_artifacts` is true.

3.  **Publish (`publish-release.yml`):**
    *   Triggered automatically when a Build completes (on `main` branch).
    *   Requires the `build-metadata` artifact to function.
    *   Creates a Draft release and opens a GitHub Issue for maintainer review.

## 🛠️ Manual Operations

### How to build manually
1.  Go to **Actions** tab -> **Build OpenSSL 3.x**.
2.  Click **Run workflow**.
3.  **Build Source:** 
    *   Select `release` for official OpenSSL releases (tags).
    *   Select `branch` for official OpenSSL branches or external OpenSSL forks.
4.  **OpenSSL Release Version, OpenSSL Branch Name or OpenSSL Fork Repo:** 
    *   Official Release: `3.4.0`
    *   Official Branch: `master`
    *   OpenSSL Fork: `user/repo/branch` (e.g., `slontis/openssl/fix-arm64ec`)
5.  *(Optional)* Check **Ignore EOL Check** for legacy builds.
6.  *(Optional)* Check **Keep raw build artifacts** for debugging compilation issues.

### How to publish a release manually
If an automatic publish fails:
1.  Go to **Actions** tab -> **Publish Release**.
2.  Click **Run workflow**.
3.  Provide the **Build Workflow Run ID**.
4.  Toggle **Create as Draft** as needed.

### Reviewing and Publishing Drafts
1. Check the **Issues** tab for a "👀 Review Required" notification.
2. Click the link to view the Draft Release.
3. Verify the artifacts and release notes.
4. Click **Edit**, uncheck "Set as a draft", and click **Publish release**.
5. Close the notification issue.
