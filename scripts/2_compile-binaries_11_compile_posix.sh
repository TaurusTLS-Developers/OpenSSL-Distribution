#!/usr/bin/env bash
# =============================================================================
# scripts/2_compile-binaries_11_compile_posix.sh
# Job: 2_compile-binaries | Step: 11 (Compile Unix POSIX)
# Compiles OpenSSL for Linux, macOS, Android, and iOS targets.
# =============================================================================
set -euo pipefail

LABEL="${1:-${LABEL:-Linux}}"
ARCH="${2:-${ARCH:-x64}}"
TARGET="${3:-${TARGET:-linux-x86_64}}"
LINKAGE="${4:-${LINKAGE:-shared}}"
MINOS="${5:-${MINOS:-}}"
PREFIX="${6:-${PREFIX:-$PWD/raw_artifact/usr/local}}"
OPENSSL_SRC_DIR="${7:-${OPENSSL_SRC_DIR:-$PWD/openssl-src}}"

echo "[COMPILE-POSIX] Compiling OpenSSL for $LABEL ($ARCH, $TARGET, $LINKAGE)..."
echo "  Source Dir : $OPENSSL_SRC_DIR"
echo "  Prefix     : $PREFIX"

if [ ! -d "$OPENSSL_SRC_DIR" ]; then
  echo "ERROR: OpenSSL source directory not found at '$OPENSSL_SRC_DIR'" >&2
  exit 1
fi

cd "$OPENSSL_SRC_DIR"

EXTRA_FLAGS=""

# --- Platform Specific Setup ---
if [ "$LABEL" == "macOS" ]; then
  if [ -n "$MINOS" ]; then
    EXTRA_FLAGS="-mmacosx-version-min=$MINOS"
  fi
elif [ "$LABEL" == "Linux" ]; then
  EXTRA_FLAGS="enable-sctp -Wl,-rpath,'\$\$ORIGIN'"
  if [ "$TARGET" == "linux-aarch64" ]; then
    export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
  fi
elif [ "$LABEL" == "Android" ]; then
  if [ -f "Configurations/15-android.conf" ]; then
    sed -i 's/-fPIC/-fPIC -Wl,-z,max-page-size=16384/g' Configurations/15-android.conf
  fi
  ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-${ANDROID_NDK_LATEST_HOME:-}}"
  if [ -n "$ANDROID_NDK_ROOT" ]; then
    export ANDROID_NDK_ROOT
    export PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
  fi
elif [ "$LABEL" == "iOS" ]; then
  XCODE_DIR="$(xcode-select -print-path)"
  if [[ "$TARGET" == *"simulator"* ]]; then
    export CROSS_TOP="$XCODE_DIR/Platforms/iPhoneSimulator.platform/Developer"
    export CROSS_SDK="iPhoneSimulator.sdk"
    if [ -n "$MINOS" ]; then
      EXTRA_FLAGS="-mios-simulator-version-min=$MINOS"
    fi
  else
    export CROSS_TOP="$XCODE_DIR/Platforms/iPhoneOS.platform/Developer"
    export CROSS_SDK="iPhoneOS.sdk"
  fi
fi

# --- Configure & Build ---
echo "[COMPILE-POSIX] Configuring OpenSSL target '$TARGET'..."
if [ "$LINKAGE" == "shared" ]; then
  ./Configure "$TARGET" shared no-tests $EXTRA_FLAGS --prefix="$PREFIX"
else
  if ! ./Configure "$TARGET" no-shared no-apps no-module no-tests $EXTRA_FLAGS --prefix="$PREFIX"; then
    echo "[COMPILE-POSIX] Fallback configure without no-apps..."
    ./Configure "$TARGET" no-shared no-module no-tests $EXTRA_FLAGS --prefix="$PREFIX"
  fi
fi

NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
echo "[COMPILE-POSIX] Compiling with make -j$NPROC..."
make -j"$NPROC"

echo "[COMPILE-POSIX] Installing software to $PREFIX..."
make install_sw DESTDIR="/"

echo "[COMPILE-POSIX] ✅ Unix compilation and installation complete."
