#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 01_merge_binaries.sh
# Job:    08_package_release
# Desc:   Merges raw downloaded artifacts into dist/ for non-macOS targets.
# =========================================================================

WS_DIR="${GITHUB_WORKSPACE:-$PWD}"
RAW_DIR="${1:-${RAW_BINARIES_DIR:-$WS_DIR/raw-binaries}}"
DIST_DIR="${2:-${DIST_DIR:-$WS_DIR/dist}}"

echo "================================================================"
echo " [MERGE-BINARIES] Raw Artifacts Source: $RAW_DIR"
echo " [MERGE-BINARIES] Distribution Target:  $DIST_DIR"
echo "================================================================"

if [ ! -d "$RAW_DIR" ]; then
    echo "FATAL: Raw binaries directory '$RAW_DIR' does not exist! Artifact download likely failed."
    exit 1
fi

mkdir -p "$DIST_DIR"

# Check if artifacts are extracted into subdirectories (standard merge-multiple: false)
shopt -s nullglob
RAW_SUBDIRS=("$RAW_DIR"/raw-*/)
shopt -u nullglob

if [ ${#RAW_SUBDIRS[@]} -gt 0 ]; then
    echo "📦 Detected nested artifact directories (${#RAW_SUBDIRS[@]} found). Merging contents into $DIST_DIR..."
    for d in "${RAW_SUBDIRS[@]}"; do
        echo "  -> Merging: $d"
        cp -a "$d"/. "$DIST_DIR/"
    done
else
    echo "📦 Detected flat artifact structure. Merging $RAW_DIR directly into $DIST_DIR..."
    cp -a "$RAW_DIR"/. "$DIST_DIR/"
fi

# Verify destination contains files
FILE_COUNT=$(find "$DIST_DIR" -type f | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "FATAL: No files were merged into '$DIST_DIR'!"
    exit 1
fi

echo "✅ Successfully merged $FILE_COUNT file(s) into '$DIST_DIR'."
exit 0
