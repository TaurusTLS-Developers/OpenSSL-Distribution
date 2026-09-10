#!/usr/bin/env bash
# =============================================================================
# scripts/2_compile-binaries_4_prepare_windows_targets.sh
# Job: 2_compile-binaries | Step: 4 (Prepare Windows Targets)
# Injects HybridCRT target configuration and dynamically configures docs disable flag.
# =============================================================================
set -euo pipefail

OPENSSL_SRC_DIR="${1:-${OPENSSL_SRC_DIR:-$PWD/openssl-src}}"
CONFIG_DIR="${2:-${CONFIG_DIR:-$PWD/config}}"

echo "[PREPARE-WIN] Preparing Windows HybridCRT targets..."
echo "  OpenSSL Source: $OPENSSL_SRC_DIR"
echo "  Config Dir    : $CONFIG_DIR"

if [ ! -d "$OPENSSL_SRC_DIR/Configurations" ]; then
  echo "ERROR: Configurations folder not found in '$OPENSSL_SRC_DIR'" >&2
  exit 1
fi

cp "$CONFIG_DIR/99-win-hybridcrt.conf" "$OPENSSL_SRC_DIR/Configurations/99-win-hybridcrt.conf"

cd "$OPENSSL_SRC_DIR"

if grep -q "no-docs" INSTALL.md 2>/dev/null; then
  echo "[PREPARE-WIN] Feature 'docs' is supported in this OpenSSL version. Disabling it in config."
  sed -i 's/"__DOCS__"/"docs"/g' Configurations/99-win-hybridcrt.conf
else
  echo "[PREPARE-WIN] Feature 'docs' is NOT supported (e.g. OpenSSL 3.0.x/3.1.x). Removing from config."
  sed -i 's/"__DOCS__"//g' Configurations/99-win-hybridcrt.conf
fi

echo "[PREPARE-WIN] ✅ Configurations/99-win-hybridcrt.conf successfully prepared."
