#!/usr/bin/env bash
# =============================================================================
# scripts/4_package-release_6_build_macos_universal.sh
# Job: 4_package-release | Step: 6 (Organize & Lipo macOS Universal)
# Rewrites Mach-O headers for relocatability, strips symbols, and fuses universal binaries with lipo.
# =============================================================================
set -euo pipefail

RAW_DIR="${1:-${RAW_DIR:-$PWD/raw-binaries}}"
DIST_DIR="${2:-${DIST_DIR:-$PWD/dist}}"

echo "[MACOS-UNIVERSAL] Building macOS Universal package..."
echo "  Raw Binaries : $RAW_DIR"
echo "  Destination  : $DIST_DIR"

if [ ! -d "$RAW_DIR" ]; then
  echo "ERROR: Raw binaries directory '$RAW_DIR' not found!" >&2
  exit 1
fi

# Rename artifact folders if run_id suffix exists
cd "$RAW_DIR"
for d in raw-macOS-*-*; do
  if [ -d "$d" ]; then
    CLEAN_NAME=$(echo "$d" | sed -E 's/-[0-9]+$//')
    if [ "$d" != "$CLEAN_NAME" ] && [ ! -d "$CLEAN_NAME" ]; then
      echo "[MACOS-UNIVERSAL] Renaming $d -> $CLEAN_NAME"
      mv "$d" "$CLEAN_NAME"
    fi
  fi
done
cd - > /dev/null

# 1. Relocate and Strip individual architectures
for arch in x64 arm64; do
  BASE_DIR="$RAW_DIR/raw-macOS-$arch-shared"
  if [ -d "$BASE_DIR" ]; then
    echo "[MACOS-UNIVERSAL] Processing shared libraries in $BASE_DIR..."
    find "$BASE_DIR" -type f \( -name "*.dylib" -o -name "*.so" -o -name "openssl" \) | while read -r target_file; do
      if [[ "$target_file" == *"openssl" ]]; then
        strip "$target_file" 2>/dev/null || true
      else
        strip -x "$target_file" 2>/dev/null || true
      fi

      if [[ "$target_file" == *".dylib" ]]; then
        install_name_tool -id "@rpath/$(basename "$target_file")" "$target_file" 2>/dev/null || true
      fi

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
  fi

  STATIC_DIR="$RAW_DIR/raw-macOS-$arch-static"
  if [ -d "$STATIC_DIR" ]; then
    echo "[MACOS-UNIVERSAL] Stripping static archives in $STATIC_DIR..."
    find "$STATIC_DIR" -type f -name "*.a" -exec strip -S {} + 2>/dev/null || true
  fi
done

# 2. Combine with Lipo
mkdir -p "$DIST_DIR/engines" "$DIST_DIR/providers" "$DIST_DIR/lib/static"

lipo_file() {
  local rel_path=$1
  local dest_path=$2
  local f_x86="$RAW_DIR/raw-macOS-x64-shared/$rel_path"
  local f_arm="$RAW_DIR/raw-macOS-arm64-shared/$rel_path"

  if [ ! -f "$f_x86" ]; then
    f_x86="$RAW_DIR/raw-macOS-x64-static/$rel_path"
    f_arm="$RAW_DIR/raw-macOS-arm64-static/$rel_path"
  fi

  if [ ! -f "$f_x86" ] || [ ! -f "$f_arm" ]; then return 0; fi
  echo "  [LIPO] Combining $dest_path"
  lipo -create -output "$dest_path" "$f_x86" "$f_arm"
}

lipo_file "openssl" "$DIST_DIR/openssl"

if [ -d "$RAW_DIR/raw-macOS-x64-shared" ]; then
  find "$RAW_DIR/raw-macOS-x64-shared" -maxdepth 1 -type f -name "*.dylib" | while read -r f; do
    lipo_file "$(basename "$f")" "$DIST_DIR/$(basename "$f")"
  done

  if [ -d "$RAW_DIR/raw-macOS-x64-shared/engines" ]; then
    find "$RAW_DIR/raw-macOS-x64-shared/engines" -type f -name "*.dylib" | while read -r f; do
      lipo_file "engines/$(basename "$f")" "$DIST_DIR/engines/$(basename "$f")"
    done
  fi

  if [ -d "$RAW_DIR/raw-macOS-x64-shared/providers" ]; then
    find "$RAW_DIR/raw-macOS-x64-shared/providers" -type f -name "*.dylib" | while read -r f; do
      lipo_file "providers/$(basename "$f")" "$DIST_DIR/providers/$(basename "$f")"
    done
  fi
fi

if [ -d "$RAW_DIR/raw-macOS-x64-static/lib/static" ]; then
  find "$RAW_DIR/raw-macOS-x64-static/lib/static" -type f -name "*.a" | while read -r f; do
    lipo_file "lib/static/$(basename "$f")" "$DIST_DIR/lib/static/$(basename "$f")"
  done
fi

if [ -f "$RAW_DIR/raw-macOS-x64-shared/install_symlinks.sh" ]; then
  cp "$RAW_DIR/raw-macOS-x64-shared/install_symlinks.sh" "$DIST_DIR/" 2>/dev/null || true
fi

echo "[MACOS-UNIVERSAL] ✅ Universal Mach-O binaries successfully fused and staged."
