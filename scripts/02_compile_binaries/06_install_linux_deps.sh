#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 06_install_linux_deps.sh
# Job:    02_compile_binaries
# Desc:   Installs build dependencies for Linux (libsctp-dev, gcc-aarch64)
# =========================================================================

ARCH="${1:-${TARGET_ARCH:-x64}}"

echo "================================================================"
echo " [LINUX-DEPS] Target Architecture: $ARCH"
echo "================================================================"

# Use sudo only if not already running as root (e.g. inside containers)
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "FATAL: Not running as root and 'sudo' is not installed!"
        exit 1
    fi
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "⚠️ Warning: apt-get not found. Skipping Debian/Ubuntu package installation."
    exit 0
fi

echo "📦 Updating apt repositories..."
$SUDO apt-get update -qq

echo "📦 Installing libsctp-dev..."
$SUDO apt-get install -y --no-install-recommends libsctp-dev

if [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    echo "📦 Installing ARM64 cross-compiler (gcc-aarch64-linux-gnu)..."
    $SUDO apt-get install -y --no-install-recommends gcc-aarch64-linux-gnu libc6-dev-arm64-cross
fi

echo "✅ Linux dependencies installed successfully."
exit 0
