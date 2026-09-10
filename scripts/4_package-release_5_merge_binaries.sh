#!/usr/bin/env bash
# =============================================================================
# scripts/4_package-release_5_merge_binaries.sh
# Job: 4_package-release | Step: 5 (Merge Binaries and Assets)
# Performs adaptive merge of raw downloaded artifact directories into dist/.
# =============================================================================
set -euo pipefail

RAW_DIR="${1:-${RAW_DIR:-$PWD/raw-binaries}}"
DIST_DIR="${2:-${DIST_DIR:-$PWD/dist}}"

echo "[MERGE-RAW] Merging raw artifacts from '$RAW_DIR' into '$DIST_DIR'..."

mkdir -p "$DIST_DIR"

if [ ! -d "$RAW_DIR" ]; then
  echo "ERROR: Raw binaries directory not found: '$RAW_DIR'" >&2
  exit 1
fi

HAS_RAW_SUBDIRS=false
for d in "$RAW_DIR"/raw-*/; do
  if [ -d "$d" ]; then
    HAS_RAW_SUBDIRS=true
    break
  fi
done

if [ "$HAS_RAW_SUBDIRS" = true ]; then
  echo "[MERGE-RAW] Detected nested artifact directory structure. Merging subdirectories..."
  for d in "$RAW_DIR"/raw-*/; do
    if [ -d "$d" ]; then
      echo "  [+] Merging $d into $DIST_DIR/"
      cp -R "$d". "$DIST_DIR/"
    fi
  done
else
  echo "[MERGE-RAW] Detected flattened artifact directory structure. Merging $RAW_DIR/ directly..."
  cp -R "$RAW_DIR"/. "$DIST_DIR/"
fi

echo "[MERGE-RAW] ✅ Merge completed into '$DIST_DIR'."
