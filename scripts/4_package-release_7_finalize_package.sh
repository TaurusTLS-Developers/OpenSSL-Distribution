#!/usr/bin/env bash
# =============================================================================
# scripts/4_package-release_7_finalize_package.sh
# Job: 4_package-release | Step: 7 (Finalize Package)
# Integrates common assets, creates version.txt and symlink scripts, and produces final .zip archive.
# =============================================================================
set -euo pipefail

LABEL="${1:-${LABEL:-Linux}}"
ARCH="${2:-${ARCH:-x64}}"
BUILD_TYPE="${3:-${BUILD_TYPE:-release}}"
ARTIFACT_VERSION="${4:-${ARTIFACT_VERSION:-3.4.0}}"
SLUGIFIED_VERSION="${5:-${SLUGIFIED_VERSION:-3.4.0}}"
COMMON_ASSETS_DIR="${6:-${COMMON_ASSETS_DIR:-$PWD/common-assets}}"
DIST_DIR="${7:-${DIST_DIR:-$PWD/dist}}"
OUTPUT_DIR="${8:-${OUTPUT_DIR:-$PWD}}"

echo "[FINALIZE-PKG] Finalizing package for $LABEL $ARCH..."
echo "  Artifact Version  : $ARTIFACT_VERSION"
echo "  Common Assets Dir : $COMMON_ASSETS_DIR"
echo "  Dist Dir          : $DIST_DIR"

if [ ! -d "$DIST_DIR" ]; then
  echo "ERROR: Distribution directory '$DIST_DIR' not found!" >&2
  exit 1
fi

mkdir -p "$DIST_DIR/include" "$DIST_DIR/doc"
if [ -d "$COMMON_ASSETS_DIR/include" ]; then
  cp -R "$COMMON_ASSETS_DIR/include"/* "$DIST_DIR/include/" 2>/dev/null || true
fi
if [ -d "$COMMON_ASSETS_DIR/share/doc" ]; then
  cp -R "$COMMON_ASSETS_DIR/share/doc"/* "$DIST_DIR/doc/" 2>/dev/null || true
fi

if [ -f "$COMMON_ASSETS_DIR/LICENSE.txt" ]; then
  cp "$COMMON_ASSETS_DIR/LICENSE.txt" "$DIST_DIR/" 2>/dev/null || true
fi
if [ -f "$COMMON_ASSETS_DIR/README.txt" ]; then
  cp "$COMMON_ASSETS_DIR/README.txt" "$DIST_DIR/" 2>/dev/null || true
fi

if [ "$BUILD_TYPE" == "branch" ]; then
  echo "branch: $SLUGIFIED_VERSION" > "$DIST_DIR/version.txt"
else
  echo "$SLUGIFIED_VERSION" > "$DIST_DIR/version.txt"
fi

if [ ! -f "$DIST_DIR/install_symlinks.sh" ]; then
  if [ "$LABEL" == "Linux" ] || [ "$LABEL" == "macOS" ]; then
    cat << 'EOF' > "$DIST_DIR/install_symlinks.sh"
#!/bin/sh
echo "Restoring shared library symlinks..."
EOF
    cd "$DIST_DIR"
    for lib in libcrypto libssl; do
      if [ "$LABEL" == "Linux" ]; then
        REAL_FILE=$(ls ${lib}.so.* 2>/dev/null | head -n 1)
        if [ -n "$REAL_FILE" ]; then
          echo "ln -sf $REAL_FILE ${lib}.so" >> install_symlinks.sh
        fi
      else
        REAL_FILE=$(ls ${lib}.*.dylib 2>/dev/null | head -n 1)
        if [ -n "$REAL_FILE" ]; then
          echo "ln -sf $REAL_FILE ${lib}.dylib" >> install_symlinks.sh
        fi
      fi
    done
    chmod +x install_symlinks.sh
    cd - > /dev/null
  fi
fi

find "$DIST_DIR" -type d -empty -delete 2>/dev/null || true

ARCHIVE_NAME="openssl-${ARTIFACT_VERSION}-${LABEL}-${ARCH}.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

echo "[FINALIZE-PKG] Creating ZIP archive: '$ARCHIVE_PATH'..."
cd "$DIST_DIR"
zip -r -y "$ARCHIVE_PATH" .
cd - > /dev/null

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "ARCHIVE_FILE=$ARCHIVE_NAME" >> "$GITHUB_ENV"
fi

echo "[FINALIZE-PKG] ✅ Package successfully finalized: '$ARCHIVE_PATH'"
