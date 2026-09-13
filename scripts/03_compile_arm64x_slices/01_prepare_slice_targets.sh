#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 01_prepare_slice_targets.sh
# Job:    03_compile_arm64x_slices
# Desc:   Copies config/99-arm64x-prep.conf into openssl-src/Configurations/
#         and resolves the __DOCS__ placeholder based on OpenSSL version.
# =========================================================================

WS_DIR="${GITHUB_WORKSPACE:-$PWD}"
DEFAULT_SRC="$WS_DIR/openssl-src"
if [ ! -d "$DEFAULT_SRC" ]; then
    DEFAULT_SRC="$WS_DIR"
fi

SRC_DIR="${1:-${SRC_DIR:-$DEFAULT_SRC}}"
CFG_DIR="${2:-${CONFIG_DIR:-$WS_DIR/config}}"

SRC_CONF="$CFG_DIR/99-win-hybridcrt.conf"
DEST_CONF="$SRC_DIR/Configurations/99-win-hybridcrt.conf"

echo "================================================================"
echo " [PREPARE-SLICE-TARGETS] Template:        $SRC_CONF"
echo " [PREPARE-SLICE-TARGETS] OpenSSL Source:  $SRC_DIR"
echo " [PREPARE-SLICE-TARGETS] Output Target:   $DEST_CONF"
echo "================================================================"

if [ ! -f "$SRC_CONF" ]; then
    echo "FATAL: Template config not found at '$SRC_CONF'!"
    exit 1
fi

if [ ! -d "$SRC_DIR/Configurations" ]; then
    echo "FATAL: OpenSSL Configurations directory not found at '$SRC_DIR/Configurations'!"
    exit 1
fi

# 1. Copy committed config from config/
cp -f "$SRC_CONF" "$DEST_CONF"

# 2. Dynamically check if 'no-docs' is supported by this OpenSSL version
INSTALL_DOC="$SRC_DIR/INSTALL.md"
if [ -f "$INSTALL_DOC" ] && grep -q "no-docs" "$INSTALL_DOC"; then
    echo "  [+] Feature 'docs' is supported. Disabling it in config."
    sed -i 's/"__DOCS__"/"docs"/g' "$DEST_CONF"
else
    echo "  [+] Feature 'docs' not supported in this version. Removing placeholder."
    sed -i 's/"__DOCS__"//g' "$DEST_CONF"
fi

# 3. Final validation
if [ ! -s "$DEST_CONF" ]; then
    echo "FATAL: Destination config '$DEST_CONF' is missing or empty!"
    exit 1
fi

echo "✅ Successfully deployed 99-arm64x-prep.conf from config/."
exit 0
