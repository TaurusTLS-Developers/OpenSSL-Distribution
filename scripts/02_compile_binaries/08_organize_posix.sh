#!/usr/bin/env bash
# =============================================================================
# scripts/2_compile-binaries_12_organize_posix.sh
# Job: 2_compile-binaries | Step: 12 (Organize Unix Binaries)
# Stages, strips, and formats Unix binaries and generates install_symlinks.sh.
# =============================================================================
set -euo pipefail

LABEL="${1:-${LABEL:-Linux}}"
LINKAGE="${2:-${LINKAGE:-shared}}"
PREFIX="${3:-${PREFIX:-$PWD/raw_artifact/usr/local}}"
DIST_DIR="${4:-${DIST_DIR:-$PWD/raw_artifact/dist}}"

echo "[ORGANIZE-POSIX] Organizing $LABEL ($LINKAGE) binaries into: $DIST_DIR"

mkdir -p "$DIST_DIR/engines" "$DIST_DIR/providers" "$DIST_DIR/lib/static"

if [ "$LINKAGE" == "shared" ]; then
  # Executable
  find "$PREFIX/bin" -type f -name "openssl" -exec cp {} "$DIST_DIR/" \; 2>/dev/null || true

  # Shared Libs
  if [ "$LABEL" == "Android" ]; then
    find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "*.so" -exec cp {} "$DIST_DIR/" \; 2>/dev/null || true
  else
    find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "libcrypto.so.*" -exec cp {} "$DIST_DIR/" \; 2>/dev/null || true
    find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "libssl.so.*" -exec cp {} "$DIST_DIR/" \; 2>/dev/null || true
    find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "libcrypto.*.dylib" -exec cp {} "$DIST_DIR/" \; 2>/dev/null || true
    find "$PREFIX/lib" "$PREFIX/lib64" -maxdepth 1 -type f -name "libssl.*.dylib" -exec cp {} "$DIST_DIR/" \; 2>/dev/null || true
  fi

  # Engines & Providers
  find "$PREFIX" -path "*/engines-*/*.so" -exec cp {} "$DIST_DIR/engines/" \; 2>/dev/null || true
  find "$PREFIX" -path "*/engines-*/*.dylib" -exec cp {} "$DIST_DIR/engines/" \; 2>/dev/null || true
  find "$PREFIX" -path "*/ossl-modules*/*.so" -exec cp {} "$DIST_DIR/providers/" \; 2>/dev/null || true
  find "$PREFIX" -path "*/ossl-modules*/*.dylib" -exec cp {} "$DIST_DIR/providers/" \; 2>/dev/null || true

  # Stripping (Non-macOS)
  if [ "$LABEL" != "macOS" ]; then
    echo "[ORGANIZE-POSIX] Stripping debug symbols from shared libraries..."
    find "$DIST_DIR" -maxdepth 1 -type f \( -name "openssl" -o -name "*.so*" \) -exec strip {} + 2>/dev/null || true
    find "$DIST_DIR/engines" "$DIST_DIR/providers" -type f -name "*.so" -exec strip {} + 2>/dev/null || true
  fi

  # Symlinks script (Linux/macOS)
  if [ "$LABEL" == "Linux" ] || [ "$LABEL" == "macOS" ]; then
    echo "[ORGANIZE-POSIX] Generating install_symlinks.sh..."
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

else
  # Static linkage
  mkdir -p "$DIST_DIR/lib/static"
  find "$PREFIX" -type f -name "*.a" -exec cp {} "$DIST_DIR/lib/static/" \; 2>/dev/null || true
  if [ "$LABEL" != "macOS" ]; then
    echo "[ORGANIZE-POSIX] Stripping debug symbols from static libraries..."
    find "$DIST_DIR/lib/static" -type f -name "*.a" -exec strip -S {} + 2>/dev/null || true
  fi
fi

find "$DIST_DIR" -type d -empty -delete || true
echo "[ORGANIZE-POSIX] ✅ Staging complete for $LABEL ($LINKAGE)."
