#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 03_finalize_package.sh
# Job:    08_package_release
# Desc:   Copies common assets (headers, docs, license), writes version.txt,
#         creates install_symlinks.sh, and creates the distribution .zip.
# =========================================================================

LABEL="${1:-${TARGET_PLATFORM:-Linux}}"
ARCH="${2:-${TARGET_ARCH:-x64}}"
BUILD_TYPE="${3:-${BUILD_TYPE:-release}}"
ARTIFACT_VERSION="${4:-${OPENSSL_VERSION:-3.4.0}}"
SLUGIFIED_VERSION="${5:-${OPENSSL_VERSION:-3.4.0}}"

WS_DIR="${GITHUB_WORKSPACE:-$PWD}"
COMMON_ASSETS_DIR="${6:-${COMMON_ASSETS_DIR:-$WS_DIR/common-assets}}"
DIST_DIR="${7:-${DIST_DIR:-$WS_DIR/dist}}"
OUTPUT_DIR="${8:-$WS_DIR}"

GITHUB_ENV="${GITHUB_ENV:-/dev/null}"

echo "================================================================"
echo " [FINALIZE-PACKAGE] Platform:         $LABEL"
echo " [FINALIZE-PACKAGE] Architecture:     $ARCH"
echo " [FINALIZE-PACKAGE] Artifact Version: $ARTIFACT_VERSION"
echo " [FINALIZE-PACKAGE] Common Assets:    $COMMON_ASSETS_DIR"
echo " [FINALIZE-PACKAGE] Dist Directory:   $DIST_DIR"
echo "================================================================"

if [ ! -d "$DIST_DIR" ]; then
    echo "FATAL: Distribution directory '$DIST_DIR' does not exist!"
    exit 1
fi

# 1. Resolve common-assets source folder (handles usr/local nested layout)
ASSETS_SRC="$COMMON_ASSETS_DIR"
if [ -d "$COMMON_ASSETS_DIR/usr/local" ]; then
    ASSETS_SRC="$COMMON_ASSETS_DIR/usr/local"
fi

mkdir -p "$DIST_DIR/include" "$DIST_DIR/doc"

echo "📄 Copying C headers and documentation..."
if [ -d "$ASSETS_SRC/include" ]; then
    cp -a "$ASSETS_SRC/include"/. "$DIST_DIR/include/"
fi
if [ -d "$ASSETS_SRC/doc" ]; then
    cp -a "$ASSETS_SRC/doc"/. "$DIST_DIR/doc/" 2>/dev/null || true
elif [ -d "$ASSETS_SRC/share/doc" ]; then
    cp -a "$ASSETS_SRC/share/doc"/. "$DIST_DIR/doc/" 2>/dev/null || true
fi

# Copy License and README
if [ -f "$ASSETS_SRC/LICENSE.txt" ]; then
    cp -f "$ASSETS_SRC/LICENSE.txt" "$DIST_DIR/"
fi
if [ -f "$ASSETS_SRC/README.txt" ]; then
    cp -f "$ASSETS_SRC/README.txt" "$DIST_DIR/"
fi
if [ "$LABEL" == "Windows" ] && [ -f "$ASSETS_SRC/LICENSE.rtf" ]; then
    cp -f "$ASSETS_SRC/LICENSE.rtf" "$DIST_DIR/"
fi

# 2. Generate version.txt metadata
echo "📝 Writing metadata version.txt..."
if [ "$BUILD_TYPE" == "branch" ]; then
    echo "branch: $SLUGIFIED_VERSION" > "$DIST_DIR/version.txt"
else
    echo "$SLUGIFIED_VERSION" > "$DIST_DIR/version.txt"
fi

# 3. Create install_symlinks.sh (POSIX only: Linux & macOS)
if [ "$LABEL" == "Linux" ] || [ "$LABEL" == "macOS" ]; then
    if [ ! -f "$DIST_DIR/install_symlinks.sh" ]; then
        echo "🔗 Generating install_symlinks.sh for $LABEL..."
        SYMLINK_SCRIPT="$DIST_DIR/install_symlinks.sh"
        
        cat << 'EOF' > "$SYMLINK_SCRIPT"
#!/bin/sh
echo "Restoring shared library symlinks..."
EOF
        
        # Detect versioned libraries and append ln -sf commands
        for lib in libcrypto libssl; do
            if [ "$LABEL" == "Linux" ]; then
                REAL_FILE=$(find "$DIST_DIR" -maxdepth 1 -name "${lib}.so.*" -type f -exec basename {} \; | head -n 1)
                if [ -n "$REAL_FILE" ]; then
                    echo "ln -sf $REAL_FILE ${lib}.so" >> "$SYMLINK_SCRIPT"
                fi
            elif [ "$LABEL" == "macOS" ]; then
                REAL_FILE=$(find "$DIST_DIR" -maxdepth 1 -name "${lib}.*.dylib" -type f -exec basename {} \; | head -n 1)
                if [ -n "$REAL_FILE" ]; then
                    echo "ln -sf $REAL_FILE ${lib}.dylib" >> "$SYMLINK_SCRIPT"
                fi
            fi
        done
        chmod +x "$SYMLINK_SCRIPT"
    fi
fi

# 4. Clean up any empty directories
find "$DIST_DIR" -type d -empty -delete 2>/dev/null || true

# 5. Create Distribution ZIP Archive
ARCHIVE_NAME="openssl-${ARTIFACT_VERSION}-${LABEL}-${ARCH}.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

echo "📦 Compressing into $ARCHIVE_PATH..."
(cd "$DIST_DIR" && zip -r -y "$ARCHIVE_PATH" .)

if [ ! -s "$ARCHIVE_PATH" ]; then
    echo "FATAL: Archive '$ARCHIVE_PATH' was not created or is empty!"
    exit 1
fi

echo "ARCHIVE_FILE=$ARCHIVE_NAME" >> "$GITHUB_ENV"
echo "✅ Package finalized successfully: $ARCHIVE_NAME ($(du -h "$ARCHIVE_PATH" | awk '{print $1}'))"
exit 0
