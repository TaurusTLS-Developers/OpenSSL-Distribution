#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 08_organize_posix.sh
# Job:    02_compile_binaries
# Desc:   Stages, separates, strips, and organizes POSIX binaries from
#         raw_artifact/usr/local into raw_artifact/dist.
# =========================================================================

LABEL="${1:-${TARGET_PLATFORM:-Linux}}"
LINKAGE="${2:-${TARGET_LINKAGE:-shared}}"
WS_DIR="${GITHUB_WORKSPACE:-$PWD}"
PREFIX="${3:-${TARGET_PREFIX:-$WS_DIR/raw_artifact/usr/local}}"
DIST_DIR="${4:-${TARGET_DIST:-$WS_DIR/raw_artifact/dist}}"

echo "================================================================"
echo " [ORGANIZE-POSIX] Platform:    $LABEL"
echo " [ORGANIZE-POSIX] Linkage:     $LINKAGE"
echo " [ORGANIZE-POSIX] Prefix Dir:  $PREFIX"
echo " [ORGANIZE-POSIX] Target Dist: $DIST_DIR"
echo "================================================================"

if [ ! -d "$PREFIX" ]; then
    echo "FATAL: Install prefix directory '$PREFIX' does not exist! Compilation likely failed."
    exit 1
fi

mkdir -p "$DIST_DIR/engines" "$DIST_DIR/providers" "$DIST_DIR/lib/static"

if [ "$LINKAGE" == "shared" ]; then
    echo "📦 Staging shared binaries..."

    # 1. CLI Executable (openssl)
    if [ -f "$PREFIX/bin/openssl" ]; then
        cp -f "$PREFIX/bin/openssl" "$DIST_DIR/"
        echo "  [+] Copied openssl CLI"
    fi

    # 2. Shared Libraries (*.so / *.dylib)
    if [ "$LABEL" == "Android" ]; then
        # Android shared libs are unversioned
        find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "*.so" -exec cp -f {} "$DIST_DIR/" \; 2>/dev/null || true
    else
        # Linux & macOS: Only copy physical versioned libraries (prevent duplicate symlinks)
        find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "libcrypto.so.*" -exec cp -f {} "$DIST_DIR/" \; 2>/dev/null || true
        find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "libssl.so.*" -exec cp -f {} "$DIST_DIR/" \; 2>/dev/null || true
        find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "libcrypto.*.dylib" -exec cp -f {} "$DIST_DIR/" \; 2>/dev/null || true
        find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "libssl.*.dylib" -exec cp -f {} "$DIST_DIR/" \; 2>/dev/null || true
    fi

    # 3. Dynamic Engines & Providers
    find "$PREFIX" -path "*/engines-*/*.so" -exec cp -f {} "$DIST_DIR/engines/" \; 2>/dev/null || true
    find "$PREFIX" -path "*/engines-*/*.dylib" -exec cp -f {} "$DIST_DIR/engines/" \; 2>/dev/null || true
    find "$PREFIX" -path "*/ossl-modules*/*.so" -exec cp -f {} "$DIST_DIR/providers/" \; 2>/dev/null || true
    find "$PREFIX" -path "*/ossl-modules*/*.dylib" -exec cp -f {} "$DIST_DIR/providers/" \; 2>/dev/null || true

    # 4. Strip Symbols (Linux and Android only; macOS stripping occurs during lipo)
    if [ "$LABEL" != "macOS" ]; then
        echo "✂️ Stripping debug symbols from shared binaries..."
        find "$DIST_DIR" -maxdepth 1 -type f \( -name "openssl" -o -name "*.so*" \) -exec strip {} + 2>/dev/null || true
        find "$DIST_DIR/engines" "$DIST_DIR/providers" -type f -name "*.so" -exec strip {} + 2>/dev/null || true
    fi

    # 5. Generate install_symlinks.sh from platform template
    if [ "$LABEL" == "Linux" ] || [ "$LABEL" == "macOS" ]; then
        echo "🔗 Generating install_symlinks.sh from template..."
        CFG_DIR="${CONFIG_DIR:-$WS_DIR/config}"
        SYMLINK_SCRIPT="$DIST_DIR/install_symlinks.sh"

        if [ "$LABEL" == "Linux" ]; then
            REAL_CRYPTO=$(find "$DIST_DIR" -maxdepth 1 -name "libcrypto.so.*" -type f -exec basename {} \; 2>/dev/null | head -n 1)
            REAL_SSL=$(find "$DIST_DIR" -maxdepth 1 -name "libssl.so.*" -type f -exec basename {} \; 2>/dev/null | head -n 1)
            TEMPLATE="$CFG_DIR/install_symlinks_linux.sh.template"
        else
            REAL_CRYPTO=$(find "$DIST_DIR" -maxdepth 1 -name "libcrypto.*.dylib" -type f -exec basename {} \; 2>/dev/null | head -n 1)
            REAL_SSL=$(find "$DIST_DIR" -maxdepth 1 -name "libssl.*.dylib" -type f -exec basename {} \; 2>/dev/null | head -n 1)
            TEMPLATE="$CFG_DIR/install_symlinks_macos.sh.template"
        fi

        if [ -n "$REAL_CRYPTO" ] && [ -n "$REAL_SSL" ] && [ -f "$TEMPLATE" ]; then
            sed -e "s|{{REAL_CRYPTO_FILE}}|$REAL_CRYPTO|g" \
                -e "s|{{REAL_SSL_FILE}}|$REAL_SSL|g" \
                "$TEMPLATE" > "$SYMLINK_SCRIPT"
            chmod +x "$SYMLINK_SCRIPT"
            echo "  [+] Generated $SYMLINK_SCRIPT"
        else
            echo "⚠️ Warning: Could not find versioned libraries or template to generate $SYMLINK_SCRIPT"
        fi
    fi

else
    echo "📦 Staging static archives (*.a)..."
    # Static libraries
    find "$PREFIX" -type f -name "*.a" -exec cp -f {} "$DIST_DIR/lib/static/" \; 2>/dev/null || true

    # Strip symbols from static archives (Non-macOS)
    if [ "$LABEL" != "macOS" ]; then
        echo "✂️ Stripping static archives..."
        find "$DIST_DIR/lib/static" -type f -name "*.a" -exec strip -S {} + 2>/dev/null || true
    fi
fi

# Clean up empty directories
find "$DIST_DIR" -type d -empty -delete 2>/dev/null || true

# Assert that files were staged
FILE_COUNT=$(find "$DIST_DIR" -type f | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "FATAL: No files were staged into '$DIST_DIR'!"
    exit 1
fi

echo "✅ Successfully organized $FILE_COUNT POSIX artifact(s) into '$DIST_DIR'."
exit 0
