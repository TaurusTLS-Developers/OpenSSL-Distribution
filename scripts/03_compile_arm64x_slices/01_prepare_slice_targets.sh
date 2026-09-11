#!/usr/bin/env bash
# =============================================================================
# scripts/2b_compile-windows-arm64x-slices_3_prepare_targets.sh
# Job: 2b_compile-windows-arm64x-slices | Step: 3 (Prepare HybridCRT Targets)
# Injects ARM64X slice configuration and checks for no-docs support.
# =============================================================================
set -euo pipefail

OPENSSL_SRC_DIR="${1:-${OPENSSL_SRC_DIR:-$PWD/openssl-src}}"
CONFIG_DIR="${2:-${CONFIG_DIR:-$PWD/config}}"

echo "[PREPARE-ARM64X] Preparing ARM64X slice configuration..."
echo "  OpenSSL Source: $OPENSSL_SRC_DIR"
echo "  Config Dir    : $CONFIG_DIR"

if [ ! -d "$OPENSSL_SRC_DIR/Configurations" ]; then
  echo "ERROR: Configurations folder not found in '$OPENSSL_SRC_DIR'" >&2
  exit 1
fi

cp "$CONFIG_DIR/99-arm64x-prep.conf" "$OPENSSL_SRC_DIR/Configurations/99-arm64x-prep.conf"

cd "$OPENSSL_SRC_DIR"

if grep -q "no-docs" INSTALL.md 2>/dev/null; then
  echo "[PREPARE-ARM64X] Feature 'docs' supported. Disabling it in config."
  sed -i 's/"__DOCS__"/"docs"/g' Configurations/99-arm64x-prep.conf
else
  echo "[PREPARE-ARM64X] Feature 'docs' not supported. Removing from config."
  sed -i 's/"__DOCS__"//g' Configurations/99-arm64x-prep.conf
fi

echo "[PREPARE-ARM64X] ✅ Configurations/99-arm64x-prep.conf successfully prepared."
