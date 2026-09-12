#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 07_compile_posix.sh
# Job:    02_compile_binaries
# Desc:   Configures and compiles OpenSSL for Linux, macOS, Android, and iOS.
# =========================================================================

# 1. Parameter resolution with intelligent defaults
LABEL="${1:-${TARGET_PLATFORM:-Linux}}"
TARGET="${2:-${TARGET_NAME:-linux-x86_64}}"
LINKAGE="${3:-${TARGET_LINKAGE:-shared}}"
WS_DIR="${GITHUB_WORKSPACE:-$PWD}"
SRC_DIR="${4:-${OPENSSL_SRC:-$WS_DIR/openssl-src}}"
if [ ! -d "$SRC_DIR" ]; then
    SRC_DIR="$WS_DIR"
fi

PREFIX="${5:-${TARGET_PREFIX:-$WS_DIR/raw_artifact/usr/local}}"
MINOS="${6:-${TARGET_MINOS:-}}"
API="${7:-${TARGET_API:-21}}"

echo "================================================================"
echo " [COMPILE-POSIX] Platform:     $LABEL"
echo " [COMPILE-POSIX] Target:       $TARGET"
echo " [COMPILE-POSIX] Linkage:      $LINKAGE"
echo " [COMPILE-POSIX] Source Dir:   $SRC_DIR"
echo " [COMPILE-POSIX] Prefix:       $PREFIX"
echo " [COMPILE-POSIX] MinOS:        $MINOS"
echo " [COMPILE-POSIX] Android API:  $API"
echo "================================================================"

if [ ! -f "$SRC_DIR/Configure" ]; then
    echo "FATAL: OpenSSL Configure script not found in '$SRC_DIR'!"
    exit 1
fi

# Ensure PREFIX is an absolute path (mandatory for OpenSSL)
mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

# 2. Switch to OpenSSL source directory
cd "$SRC_DIR"

EXTRA_FLAGS=""

# 3. Platform-Specific Setup
case "$LABEL" in
    macOS)
        if [ -n "$MINOS" ]; then
            EXTRA_FLAGS="-mmacosx-version-min=$MINOS"
        fi
        ;;
    Linux)
        # Pass '\$\$ORIGIN' so Make turns it into literal '$ORIGIN' in RUNPATH
        EXTRA_FLAGS="enable-sctp -Wl,-rpath,'\$\$ORIGIN'"
        if [ "$TARGET" == "linux-aarch64" ]; then
            export CROSS_COMPILE="aarch64-linux-gnu-"
            echo "  [+] Set CROSS_COMPILE=aarch64-linux-gnu-"
        fi
        ;;
    Android)
        # Idempotent: Patch 16K max-page-size only once
        ANDROID_CONF="Configurations/15-android.conf"
        if [ -f "$ANDROID_CONF" ] && ! grep -q "max-page-size" "$ANDROID_CONF"; then
            echo "  [+] Injecting 16K page alignment (-Wl,-z,max-page-size=16384) into $ANDROID_CONF"
            sed -i 's/-fPIC/-fPIC -Wl,-z,max-page-size=16384/g' "$ANDROID_CONF"
        fi

        NDK_ROOT="${ANDROID_NDK_ROOT:-${ANDROID_NDK_LATEST_HOME:-}}"
        if [ -z "$NDK_ROOT" ]; then
            echo "FATAL: ANDROID_NDK_ROOT or ANDROID_NDK_LATEST_HOME must be set for Android builds!"
            exit 1
        fi
        export ANDROID_NDK_ROOT="$NDK_ROOT"
        export PATH="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
        echo "  [+] Android NDK configured: $NDK_ROOT"
        ;;
    iOS)
        XCODE_DEV="$(xcode-select -print-path)"
        if [[ "$TARGET" == *"simulator"* ]]; then
            export CROSS_TOP="$XCODE_DEV/Platforms/iPhoneSimulator.platform/Developer"
            export CROSS_SDK="iPhoneSimulator.sdk"
            if [ -n "$MINOS" ]; then
                EXTRA_FLAGS="-mios-simulator-version-min=$MINOS"
            fi
        else
            export CROSS_TOP="$XCODE_DEV/Platforms/iPhoneOS.platform/Developer"
            export CROSS_SDK="iPhoneOS.sdk"
            if [ -n "$MINOS" ]; then
                EXTRA_FLAGS="-miphoneos-version-min=$MINOS"
            fi
        fi
        echo "  [+] iOS Toolchain configured: $CROSS_SDK ($CROSS_TOP)"
        ;;
    *)
        echo "FATAL: Unsupported POSIX platform: '$LABEL'"
        exit 1
        ;;
esac

# 4. Run OpenSSL Configure
echo "⚙️ Configuring OpenSSL for $TARGET ($LINKAGE)..."
if [ "$LINKAGE" == "shared" ]; then
    # Shared builds enable tests exclusion
    ./Configure "$TARGET" shared no-tests $EXTRA_FLAGS --prefix="$PREFIX"
else
    # Static builds: Attempt with no-apps (OpenSSL 3.2+), fallback to without no-apps (OpenSSL 3.0/3.1)
    if ! ./Configure "$TARGET" no-shared no-apps no-module no-tests $EXTRA_FLAGS --prefix="$PREFIX"; then
        echo "⚠️ 'no-apps' not supported in this OpenSSL version. Falling back without no-apps..."
        ./Configure "$TARGET" no-shared no-module no-tests $EXTRA_FLAGS --prefix="$PREFIX"
    fi
fi

# 5. Compile and Install Software
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
echo "🔨 Compiling OpenSSL ($NPROC parallel jobs)..."
make -j"$NPROC"

echo "📦 Installing software to $PREFIX..."
make install_sw DESTDIR="/"

echo "✅ POSIX compile and install completed successfully."
exit 0
