#!/usr/bin/env bash
# =============================================================================
# scripts/2_compile-binaries_10_install_linux_deps.sh
# Job: 2_compile-binaries | Step: 10 (Install Linux Dependencies)
# Installs libsctp-dev and cross-compilation toolchains if on Linux.
# =============================================================================
set -euo pipefail

ARCH="${1:-${ARCH:-x64}}"

echo "[INSTALL-DEPS] Installing Linux dependencies for arch: $ARCH..."

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y libsctp-dev
  if [ "$ARCH" == "arm64" ]; then
    echo "[INSTALL-DEPS] Installing aarch64 cross-compiler toolchain..."
    sudo apt-get install -y gcc-aarch64-linux-gnu libc6-dev-arm64-cross
  fi
else
  echo "[INSTALL-DEPS] Non-Debian/apt system detected. Ensure libsctp-dev and cross-toolchain are present."
fi

echo "[INSTALL-DEPS] ✅ Dependencies installed."
