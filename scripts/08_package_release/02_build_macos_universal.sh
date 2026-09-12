#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 02_build_macos_universal.sh
# Job:    08_package_release
# Desc:   Rewrites Mach-O headers, strips symbols, and creates Universal
#         (Fat) binaries via lipo on macOS runners.
# =========================================================================

WS_DIR="${GITHUB_WORKSPACE:-$PWD}"
RAW_DIR="${1:-${RAW_BINARIES_DIR:-$WS_DIR/raw-binaries}}"
DIST_DIR="${2:-${DIST_DIR:-$WS_DIR/dist}}"

echo "================================================================"
echo " [MACOS-UNIVERSAL] Raw Source:   $RAW_DIR"
echo " [MACOS-UNIVERSAL] Dist Target:  $DIST_DIR"
echo "================================================================"

for tool in otool install_name_tool lipo strip; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "FATAL: Required macOS tool '$tool' not found. This script must run on macOS!"
        exit 1
    fi
done

# 1. Resolve architecture slice directories dynamically (handles run_id suffix automatically)
resolve_slice_dir() {
    local pattern="$1"
    local dir
    dir=$(find "$RAW_DIR" -maxdepth 1 -type d -name "$pattern" | head -n 1)
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        echo "FATAL: Could not locate slice directory matching '$pattern' in $RAW_DIR!" >&2
        exit 1
    fi
    echo "$dir"
}

SHARED_X64=$(resolve_slice_dir "raw-macOS-x64-shared*")
STATIC_X64=$(resolve_slice_dir "raw-macOS-x64-static*")
SHARED_ARM64=$(resolve_slice_dir "raw-macOS-arm64-shared*")
STATIC_ARM64=$(resolve_slice_dir "raw-macOS-arm64-static*")

echo "  [+] Resolved x64 Shared:   $SHARED_X64"
echo "  [+] Resolved arm64 Shared: $SHARED_ARM64"

# 2. Relocate and Strip individual architecture slices
for base_dir in "$SHARED_X64" "$SHARED_ARM64"; do
    echo "⚙️ Relocating Mach-O binaries in $base_dir..."
    find "$base_dir" -type f \( -name "*.dylib" -o -name "*.so" -o -name "openssl" \) | while read -r target_file; do
        if [[ "$target_file" == *"openssl" ]]; then
            strip "$target_file" 2>/dev/null || true
        else
            strip -x "$target_file" 2>/dev/null || true
        fi

        if [[ "$target_file" == *".dylib" ]]; then
            install_name_tool -id "@rpath/$(basename "$target_file")" "$target_file" 2>/dev/null || true
        fi

        # Rewrite hardcoded /usr/local/lib dependencies to relocatable @loader_path
        DEPS=$(otool -L "$target_file" 2>/dev/null | awk '/\/usr\/local\/lib\/lib/ {print $1}')
        for dep in $DEPS; do
            depname=$(basename "$dep")
            if [[ "$target_file" == *"engines"* ]] || [[ "$target_file" == *"providers"* ]]; then
                install_name_tool -change "$dep" "@loader_path/../$depname" "$target_file" 2>/dev/null || true
            else
                install_name_tool -change "$dep" "@loader_path/$depname" "$target_file" 2>/dev/null || true
            fi
        done

        install_name_tool -add_rpath "@executable_path" "$target_file" 2>/dev/null || true
        install_name_tool -add_rpath "@loader_path" "$target_file" 2>/dev/null || true
    done
done

# Strip static libraries (.a)
for static_dir in "$STATIC_X64" "$STATIC_ARM64"; do
    find "$static_dir" -type f -name "*.a" -exec strip -S {} + 2>/dev/null || true
done

# 3. Create destination directory structure
mkdir -p "$DIST_DIR/engines" "$DIST_DIR/providers" "$DIST_DIR/lib/static"

# Helper function to fuse two architecture files with lipo
lipo_combine() {
    local rel_path="$1"
    local dest_path="$2"
    local f_x64="$SHARED_X64/$rel_path"
    local f_arm="$SHARED_ARM64/$rel_path"

    if [ ! -f "$f_x64" ]; then
        f_x64="$STATIC_X64/$rel_path"
        f_arm="$STATIC_ARM64/$rel_path"
    fi

    if [ -f "$f_x64" ] && [ -f "$f_arm" ]; then
        echo "  [lipo] Fusing: $(basename "$dest_path")"
        lipo -create -output "$dest_path" "$f_x64" "$f_arm"
    else
        echo "⚠️ Warning: Missing architecture file for $rel_path (skipped)"
    fi
}

# 4. Fuse Executable, Dylibs, Modules, and Static Archives
echo "🔨 Combining architecture slices into Universal Fat binaries..."
lipo_combine "openssl" "$DIST_DIR/openssl"

find "$SHARED_X64" -maxdepth 1 -type f -name "*.dylib" | while read -r f; do
    filename=$(basename "$f")
    lipo_combine "$filename" "$DIST_DIR/$filename"
done

if [ -d "$SHARED_X64/engines" ]; then
    find "$SHARED_X64/engines" -type f -name "*.dylib" | while read -r f; do
        filename=$(basename "$f")
        lipo_combine "engines/$filename" "$DIST_DIR/engines/$filename"
    done
fi

if [ -d "$SHARED_X64/providers" ]; then
    find "$SHARED_X64/providers" -type f -name "*.dylib" | while read -r f; do
        filename=$(basename "$f")
        lipo_combine "providers/$filename" "$DIST_DIR/providers/$filename"
    done
fi

if [ -d "$STATIC_X64/lib/static" ]; then
    find "$STATIC_X64/lib/static" -type f -name "*.a" | while read -r f; do
        filename=$(basename "$f")
        lipo_combine "lib/static/$filename" "$DIST_DIR/lib/static/$filename"
    done
fi

# Copy symlink script if present
if [ -f "$SHARED_X64/install_symlinks.sh" ]; then
    cp -f "$SHARED_X64/install_symlinks.sh" "$DIST_DIR/"
fi

# 5. Verify Universal Binary Output
echo "🔍 Verifying Universal Mach-O architectures on '$DIST_DIR/openssl'..."
ARCH_INFO=$(lipo -info "$DIST_DIR/openssl" 2>&1)
echo "  $ARCH_INFO"
if [[ "$ARCH_INFO" != *"x86_64"* ]] || [[ "$ARCH_INFO" != *"arm64"* ]]; then
    echo "FATAL: '$DIST_DIR/openssl' is not a valid Universal binary containing both x86_64 and arm64!"
    exit 1
fi

echo "✅ macOS Universal binaries successfully compiled and verified."
exit 0
