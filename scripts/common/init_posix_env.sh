#!/usr/bin/env bash
# =============================================================================
# scripts/common/init_posix_env.sh
# Detects and exports environment variables for POSIX compilation targets.
# Supports Linux (native & cross aarch64), macOS, Android NDK, and iOS SDKs.
# =============================================================================
set -euo pipefail

LABEL="${1:-${LABEL:-$(uname -s)}}"
TARGET="${2:-${TARGET:-}}"
ARCH="${3:-${ARCH:-}}"

echo "[INIT-POSIX-ENV] Initializing environment for Platform: $LABEL, Target: $TARGET, Arch: $ARCH"

case "$LABEL" in
  Linux|linux)
    if [ "$TARGET" = "linux-aarch64" ] || [ "$ARCH" = "arm64" ]; then
      export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
      echo "[INIT-POSIX-ENV] Set CROSS_COMPILE=$CROSS_COMPILE"
    fi
    ;;
  Android|android)
    NDK_ROOT="${ANDROID_NDK_ROOT:-${ANDROID_NDK_LATEST_HOME:-}}"
    if [ -z "$NDK_ROOT" ] || [ ! -d "$NDK_ROOT" ]; then
      echo "ERROR: Android NDK not found. Set ANDROID_NDK_ROOT or ANDROID_NDK_LATEST_HOME." >&2
      exit 1
    fi
    export ANDROID_NDK_ROOT="$NDK_ROOT"
    export PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
    echo "[INIT-POSIX-ENV] Configured Android NDK toolchain from $ANDROID_NDK_ROOT"
    ;;
  iOS|ios)
    XCODE_PATH="$(xcode-select -print-path)"
    if [[ "$TARGET" == *"simulator"* ]] || [[ "$ARCH" == *"sim"* ]]; then
      export CROSS_TOP="$XCODE_PATH/Platforms/iPhoneSimulator.platform/Developer"
      export CROSS_SDK="iPhoneSimulator.sdk"
    else
      export CROSS_TOP="$XCODE_PATH/Platforms/iPhoneOS.platform/Developer"
      export CROSS_SDK="iPhoneOS.sdk"
    fi
    echo "[INIT-POSIX-ENV] Configured iOS toolchain: CROSS_TOP=$CROSS_TOP, CROSS_SDK=$CROSS_SDK"
    ;;
  Darwin|macOS|macos)
    echo "[INIT-POSIX-ENV] Configured macOS Apple toolchain."
    ;;
  *)
    echo "[INIT-POSIX-ENV] Standard POSIX environment ready."
    ;;
esac
