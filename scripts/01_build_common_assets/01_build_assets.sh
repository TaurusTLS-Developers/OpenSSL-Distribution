#!/usr/bin/env bash
# =============================================================================
# scripts/1_build-common-assets_3_build.sh
# Job: 1_build-common-assets | Step: 3 (Build Common Assets)
# Compiles C headers, HTML docs, and stages LICENSE and README text.
# =============================================================================
set -euo pipefail

OPENSSL_SRC_DIR="${1:-${OPENSSL_SRC_DIR:-$PWD/openssl-src}}"
DEST_DIR="${2:-${DEST_DIR:-$PWD/common-assets}}"
CONFIG_DIR="${3:-${CONFIG_DIR:-$PWD/config}}"

echo "[BUILD-ASSETS] Building OpenSSL common assets..."
echo "  OpenSSL Source : $OPENSSL_SRC_DIR"
echo "  Destination    : $DEST_DIR"
echo "  Config Dir     : $CONFIG_DIR"

if [ ! -d "$OPENSSL_SRC_DIR" ]; then
  echo "ERROR: OpenSSL source directory not found at '$OPENSSL_SRC_DIR'" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

cd "$OPENSSL_SRC_DIR"
echo "[BUILD-ASSETS] Configuring linux-x86_64 for headers and doc generation..."
./Configure linux-x86_64 no-tests --prefix=/usr/local

NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
echo "[BUILD-ASSETS] Installing development headers using -j$NPROC..."
make -j"$NPROC" install_dev DESTDIR="$DEST_DIR"

echo "[BUILD-ASSETS] Installing HTML docs..."
make install_html_docs DESTDIR="$DEST_DIR" || true

# Include plain-text License
if [ -f "LICENSE.txt" ]; then
  cp LICENSE.txt "$DEST_DIR/usr/local/"
elif [ -f "LICENSE" ]; then
  cp LICENSE "$DEST_DIR/usr/local/LICENSE.txt"
fi

# Include package README from config/
if [ -f "$CONFIG_DIR/README.txt" ]; then
  cp "$CONFIG_DIR/README.txt" "$DEST_DIR/usr/local/README.txt"
else
  echo "WARNING: $CONFIG_DIR/README.txt not found!"
fi

# Remove unnecessary large directories
echo "[BUILD-ASSETS] Cleaning binary and library directories from common assets..."
rm -rf "$DEST_DIR/usr/local/lib" "$DEST_DIR/usr/local/lib64" "$DEST_DIR/usr/local/bin" "$DEST_DIR/usr/local/ssl"

echo "[BUILD-ASSETS] ✅ Common assets successfully compiled into '$DEST_DIR/usr/local'."
