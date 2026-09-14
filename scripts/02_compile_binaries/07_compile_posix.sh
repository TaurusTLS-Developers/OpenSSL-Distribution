#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 07_compile_posix.sh
# Job:    02_compile_binaries
# Desc:   Configures and compiles OpenSSL for Linux, macOS, Android, and iOS.
# =========================================================================

# 1. Parameter resolution (Fail fast if mandatory arguments are missing)
LABEL="${1:-${TARGET_PLATFORM:-}}"
TARGET="${2:-${TARGET_NAME:-}}"
LINKAGE="${3:-${TARGET_LINKAGE:-}}"

if [ -z "$LABEL" ] || [ -z "$TARGET" ] || [ -z "$LINKAGE" ]; then
    echo "FATAL: Missing mandatory parameters! (LABEL='$LABEL', TARGET='$TARGET', LINKAGE='$LINKAGE')"
    exit 1
fi

WS_DIR="${GITHUB_WORKSPACE:-$PWD}"
DEFAULT_SRC="$WS_DIR/openssl-src"
if [ ! -d "$DEFAULT_SRC" ]; then
    DEFAULT_SRC="$WS_DIR"
fi

SRC_DIR="${4:-${OPENSSL_SRC:-$DEFAULT_SRC}}"
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

# Ensure PREFIX is an absolute path
mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"

# 2. Switch to OpenSSL source directory
cd "$SRC_DIR"

EXTRA_FLAGS=""

# 3. Platform-Specific Setup
case "$LABEL" in
    Linux)
        # Enable SCTP and relative RPATH only for Linux
        EXTRA_FLAGS="enable-sctp -Wl,-rpath,'\$\$ORIGIN'"
        if [ "$TARGET" == "linux-aarch64" ]; then
            export CROSS_COMPILE="aarch64-linux-gnu-"
            echo "  [+] Set CROSS_COMPILE=aarch64-linux-gnu-"
        fi
        ;;
    macOS)
        # Explicitly disable SCTP on macOS
        EXTRA_FLAGS="no-sctp"
        if [ -n "$MINOS" ]; then
            EXTRA_FLAGS="$EXTRA_FLAGS -mmacosx-version-min=$MINOS"
        fi
        ;;
    Android)
        # Explicitly disable SCTP on Android and ensure 16K alignment
        EXTRA_FLAGS="no-sctp"
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
        ;;
    iOS)
        # Explicitly disable SCTP on iOS (sctp headers do not exist on iOS)
        EXTRA_FLAGS="no-sctp"
        XCODE_DEV="$(xcode-select -print-path)"
        if [[ "$TARGET" == *"simulator"* ]]; then
            export CROSS_TOP="$XCODE_DEV/Platforms/iPhoneSimulator.platform/Developer"
            export CROSS_SDK="iPhoneSimulator.sdk"
            if [ -n "$MINOS" ]; then
                EXTRA_FLAGS="$EXTRA_FLAGS -mios-simulator-version-min=$MINOS"
            fi
        else
            export CROSS_TOP="$XCODE_DEV/Platforms/iPhoneOS.platform/Developer"
            export CROSS_SDK="iPhoneOS.sdk"
            if [ -n "$MINOS" ]; then
                EXTRA_FLAGS="$EXTRA_FLAGS -miphoneos-version-min=$MINOS"
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
    ./Configure "$TARGET" shared no-tests $EXTRA_FLAGS --prefix="$PREFIX"
else
    if ! ./Configure "$TARGET" no-shared no-apps no-module no-tests $EXTRA_FLAGS --prefix="$PREFIX"; then
        echo "⚠️ 'no-apps' not supported in this OpenSSL version. Falling back without no-apps..."
        ./Configure "$TARGET" no-shared no-module no-tests $EXTRA_FLAGS --prefix="$PREFIX"
    fi
fi

# 5. Compile and Install
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
echo "🔨 Compiling OpenSSL ($NPROC parallel jobs)..."
make -j"$NPROC"

echo "📦 Installing software to $PREFIX..."
make install_sw DESTDIR="/"

echo "✅ POSIX compile and install completed successfully for $LABEL ($TARGET)."
exit 0