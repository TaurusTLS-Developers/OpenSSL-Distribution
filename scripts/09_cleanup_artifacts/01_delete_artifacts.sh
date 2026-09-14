#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 01_delete_artifacts.sh
# Job:    09_cleanup_artifacts
# Desc:   Deletes intermediate raw-* and slice-* artifacts for a specific
#         workflow run using the GitHub CLI (gh api).
# =========================================================================

RUN_ID="${1:-${RUN_ID:-${GITHUB_RUN_ID:-}}}"
REPO="${2:-${REPO:-${GITHUB_REPOSITORY:-}}}"

echo "================================================================"
echo " [CLEANUP-ARTIFACTS] Target Run ID:    ${RUN_ID:-<Not Provided>}"
echo " [CLEANUP-ARTIFACTS] Repository:       ${REPO:-<Not Provided>}"
echo "================================================================"

# 1. Local execution and environment guard
if [ -z "$RUN_ID" ] || [ -z "$REPO" ]; then
    echo "ℹ️ Notice: RUN_ID or REPOSITORY not specified. Skipping artifact cleanup (likely running locally)."
    exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "⚠️ Warning: GitHub CLI ('gh') is not installed. Skipping artifact deletion."
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "FATAL: 'jq' utility is required for JSON artifact parsing but was not found!"
    exit 1
fi

if [ -z "${GH_TOKEN:-}" ]; then
    echo "⚠️ Warning: GH_TOKEN is not set. Skipping artifact deletion."
    exit 0
fi

echo "🔍 Fetching artifact list for workflow run $RUN_ID..."
ARTIFACTS_JSON=$(gh api "repos/$REPO/actions/runs/$RUN_ID/artifacts" --paginate 2>/dev/null || echo "{}")

# 2. Extract IDs of intermediate artifacts matching:
#    - 'raw-*-<RUN_ID>'
#    - 'slice-*-<RUN_ID>'
#    - 'openssl-common-assets-<RUN_ID>'
IDS=$(echo "$ARTIFACTS_JSON" | jq -r '
  .artifacts[]? |
  select(
    ((.name | startswith("raw-") or startswith("slice-")) and (.name | endswith("-'$RUN_ID'"))) or
    (.name == "openssl-common-assets-'$RUN_ID'")
  ) | .id' 2>/dev/null || echo "")

if [ -z "$IDS" ] || [ "$IDS" == "null" ]; then
    echo "ℹ️ No intermediate artifacts found for deletion (all clean)."
    exit 0
fi

TOTAL_COUNT=$(echo "$IDS" | wc -w)
echo "🗑️ Found $TOTAL_COUNT intermediate artifact(s) to delete."

DELETED_COUNT=0
for id in $IDS; do
    echo "  [-] Deleting artifact ID: $id"
    if gh api -X DELETE "repos/$REPO/actions/artifacts/$id" >/dev/null 2>&1; then
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        echo "  ⚠️ Warning: Failed to delete artifact ID: $id (continuing)"
    fi
done

echo "✅ Cleanup complete. Successfully deleted $DELETED_COUNT of $TOTAL_COUNT intermediate artifact(s)."
exit 0
