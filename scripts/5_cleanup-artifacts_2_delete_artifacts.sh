#!/usr/bin/env bash
# =============================================================================
# scripts/5_cleanup-artifacts_2_delete_artifacts.sh
# Job: 5_cleanup-artifacts | Step: 2 (Delete Intermediate Artifacts)
# Safely removes intermediate raw, slice, and common assets artifacts from GitHub Actions run.
# =============================================================================
set -euo pipefail

REPO="${1:-${GITHUB_REPOSITORY:-}}"
RUN_ID="${2:-${GITHUB_RUN_ID:-}}"

if [ -z "$REPO" ] || [ -z "$RUN_ID" ]; then
  echo "ERROR: GITHUB_REPOSITORY and GITHUB_RUN_ID are required for artifact cleanup." >&2
  exit 1
fi

echo "[CLEANUP] Fetching intermediate artifacts for $REPO run $RUN_ID..."

ARTIFACTS=$(gh api "repos/$REPO/actions/runs/$RUN_ID/artifacts" --paginate)

IDS=$(echo "$ARTIFACTS" | jq -r ".artifacts[] | select (.name | ((startswith(\"raw-\") or startswith(\"slice-\")) and endswith(\"-$RUN_ID\")) or . == \"openssl-common-assets-$RUN_ID\") | .id")

if [ -z "$IDS" ] || [ "$IDS" == "null" ]; then
  echo "[CLEANUP] No intermediate artifacts found to delete."
  exit 0
fi

for id in $IDS; do
  echo "[CLEANUP] Deleting intermediate artifact ID: $id"
  gh api -X DELETE "repos/$REPO/actions/artifacts/$id" || echo "[CLEANUP] Failed to delete artifact ID: $id" ; true
done

echo "[CLEANUP] ✅ Intermediate artifact cleanup completed."
