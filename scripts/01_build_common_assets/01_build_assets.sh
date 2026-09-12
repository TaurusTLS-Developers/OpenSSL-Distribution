#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 01_build_assets.sh
# Job:    01_build_common_assets
# Desc:   Configures OpenSSL on Linux to compile C headers (include/),
#         HTML documentation (doc/), LICENSE.txt, and distribution README.txt.
# =========================================================================

# 1. Parameter resolution with intelligent local fallbacks
WS_DIR="${GITHUB_WORKSPACE:-$PWD}"
DEFAULT_SRC="$WS_DIR/openssl-src"
if [ ! -d "$DEFAULT_SRC" ]; then
    DEFAULT_SRC="$WS_DIR"
fi

SRC_DIR="${1:-${SRC_DIR:-$DEFAULT_SRC}}"
DEST_ROOT="${2:-${COMMON_ASSETS_DIR:-$WS_DIR/common-assets}}"

# Guarantee absolute path for DESTDIR (mandatory for OpenSSL make install)
mkdir -p "$DEST_ROOT"
DEST_ROOT="$(cd "$DEST_ROOT" && pwd)"
TARGET_DIR="$DEST_ROOT/usr/local"

echo "================================================================"
echo " [BUILD-COMMON-ASSETS] Source Directory:  $SRC_DIR"
echo " [BUILD-COMMON-ASSETS] Staging Root:      $DEST_ROOT"
echo " [BUILD-COMMON-ASSETS] Install Target:    $TARGET_DIR"
echo "================================================================"

if [ ! -f "$SRC_DIR/Configure" ]; then
    echo "FATAL: OpenSSL Configure script not found in '$SRC_DIR'!"
    exit 1
fi

# 2. Switch to OpenSSL source directory
cd "$SRC_DIR"

# 3. Configure for Linux x86_64 to generate headers and build targets
echo "⚙️ Configuring OpenSSL for common assets extraction..."
./Configure linux-x86_64 no-tests --prefix=/usr/local

# 4. Build and install C headers (install_dev)
echo "📦 Compiling and installing headers (install_dev)..."
NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
make -j"$NPROC" install_dev DESTDIR="$DEST_ROOT"

# 5. Build and install HTML documentation (install_html_docs)
echo "📚 Generating HTML documentation..."
make install_html_docs DESTDIR="$DEST_ROOT" || {
    echo "⚠️ Warning: make install_html_docs returned an error or is unsupported in this version. Continuing."
}

# 6. Copy plain-text LICENSE.txt from source root
echo "📄 Staging LICENSE.txt..."
if [ -f "LICENSE.txt" ]; then
    cp -f "LICENSE.txt" "$TARGET_DIR/"
elif [ -f "LICENSE" ]; then
    cp -f "LICENSE" "$TARGET_DIR/LICENSE.txt"
else
    echo "FATAL: LICENSE file not found in '$SRC_DIR'!"
    exit 1
fi

# 7. Generate distribution README.txt
echo "📝 Generating distribution README.txt..."
cat << 'EOF' > "$TARGET_DIR/README.txt"
OpenSSL Distribution Package
============================

This package contains the OpenSSL executable, shared libraries, static libraries (stripped), C headers, and documentation.

Package Layout:
---------------
* version.txt         - OpenSSL version in this package [non-redistributable]
* openssl             - The OpenSSL command-line utility [redistributable/optional]
* libcrypto / libssl  - Shared libraries [redistributable/required] 
* install_symlinks.sh - (POSIX only) Script to restore shared library symlinks [redistributable/optional] 
* engines/            - OpenSSL dynamic engines [redistributable/optional] 
* providers/          - OpenSSL dynamic providers [redistributable/optional] 
* doc/                - Developer Documentation [non-redistributable] 
* include/            - C Header files [non-redistributable] 
* lib/import/         - Import libraries (Windows only) [non-redistributable] 
* lib/static/         - Static libraries (.lib / .a) [non-redistributable]

Linking Instructions:
---------------------
* Windows Dynamic: Link against the import libraries in `lib/import/` (which point to the DLLs in the root).
* Windows Static:  Link against the static libraries in `lib/static/` (Compiled with /MT HybridCRT).
* POSIX Dynamic:   Link directly against the shared libraries (.so / .dylib) in the root directory.
* POSIX Static:    Link against the static archives (.a) in `lib/static/`.

Deployment Instructions (Linux / macOS / Unix):
-----------------------------------------------
Windows file systems fail to extract Unix symbolic links. To ensure cross-platform compatibility, this archive contains only the physical shared library files.

If this package includes the 'install_symlinks.sh' script, you MUST run it from the root of the extracted directory to recreate the required library symlinks (e.g., libcrypto.so -> libcrypto.so.X).

$ cd <extracted_directory>
$ sh ./install_symlinks.sh

Windows Users:
--------------
Windows does not use symlinks for OpenSSL DLLs. You can safely ignore or delete the shell script.
EOF

# 8. Remove compiled binaries/libraries from common-assets (only headers and docs belong here)
echo "🧹 Purging binary artifacts from common-assets..."
rm -rf "$TARGET_DIR/lib" "$TARGET_DIR/lib64" "$TARGET_DIR/bin" "$TARGET_DIR/ssl"

# 9. Post-build assertions
echo "🔍 Validating generated common assets..."
if [ ! -f "$TARGET_DIR/include/openssl/ssl.h" ]; then
    echo "FATAL: OpenSSL C headers were not installed to '$TARGET_DIR/include/openssl/ssl.h'!"
    exit 1
fi

if [ ! -f "$TARGET_DIR/LICENSE.txt" ]; then
    echo "FATAL: Staged LICENSE.txt missing from '$TARGET_DIR'!"
    exit 1
fi

if [ ! -f "$TARGET_DIR/README.txt" ]; then
    echo "FATAL: Staged README.txt missing from '$TARGET_DIR'!"
    exit 1
fi

echo "✅ Common assets successfully built and validated in '$TARGET_DIR'."
exit 0
