#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# Script: 01_check_eol.sh
# Job:    00_validate_version
# Desc:   Validates OpenSSL version/branch, checks EOL status, resolves
#         git commit SHA, extracts Major.Minor, and outputs metadata.
# =========================================================================

# 1. Parameter resolution (CLI Arguments -> Env Variables -> Defaults)
VERSION="${1:-${VERSION:-${OPENSSL_VERSION:-3.4.0}}}"
BUILD_TYPE="${2:-${BUILD_TYPE:-release}}"
IGNORE_EOL="${3:-${IGNORE_EOL:-false}}"

# Emulate GITHUB_OUTPUT for local execution
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/stdout}"

echo "================================================================"
echo " [VALIDATE-VERSION] Target Version: $VERSION"
echo " [VALIDATE-VERSION] Build Type:     $BUILD_TYPE"
echo " [VALIDATE-VERSION] Ignore EOL:     $IGNORE_EOL"
echo "================================================================"

TARGET_REPO="openssl/openssl"
IS_FORK="false"

# 2. Extract Major.Minor version (e.g. 3.0, 3.4, 4.0)
MAJOR_MINOR=$(echo "$VERSION" | cut -d. -f1,2)

# 3. Generate deterministic RFC 4122 UUIDv5 for InnoSetup AppId
if command -v python3 >/dev/null 2>&1; then
    INNO_APP_ID=$(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, 'taurustls.openssl.inno.$MAJOR_MINOR'))" | tr '[:lower:]' '[:upper:]')
else
    # Fallback to MD5 GUID if python3 is not installed on local host
    INNO_APP_ID=$(echo -n "taurustls.openssl.inno.$MAJOR_MINOR" | md5sum | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12}).*/\1-\2-\3-\4-\5/' | tr '[:lower:]' '[:upper:]')
fi

# 4. Resolve Tags, SHAs, and EOL dates
if [ "$BUILD_TYPE" == "release" ]; then
    echo "🔍 Checking EOL date for OpenSSL $MAJOR_MINOR..."
    
    # Query OpenSSL release metadata
    EOL_JSON=$(curl -s --connect-timeout 10 --max-time 30 https://raw.githubusercontent.com/openssl/release-metadata/refs/heads/main/data.json || echo "{}")
    EOL_DATE_RAW=$(echo "$EOL_JSON" | jq -r ".[\"$MAJOR_MINOR\"].eol // empty" 2>/dev/null || echo "")

    if [ -n "$EOL_DATE_RAW" ]; then
        # Parse EOL date to Unix epoch (handles various date string formats)
        EOL_EPOCH=$(date -d "$EOL_DATE_RAW" +%s 2>/dev/null || date -d "01 $EOL_DATE_RAW" +%s 2>/dev/null || echo 0)
        TODAY_EPOCH=$(date +%s)

        if [ "$EOL_EPOCH" -gt 0 ] && [ "$TODAY_EPOCH" -gt "$EOL_EPOCH" ]; then
            echo "❌ OpenSSL $MAJOR_MINOR reached End-of-Life (EOL) on $(date -d "@$EOL_EPOCH" +%Y-%m-%d)."
            if [ "$IGNORE_EOL" != "true" ]; then
                echo "FATAL: Aborting build. Check 'Ignore EOL' input to force build."
                exit 1
            fi
            echo "⚠️ 'Ignore EOL' is enabled. Continuing build despite EOL."
        else
            echo "✅ OpenSSL $MAJOR_MINOR is active (EOL date: $EOL_DATE_RAW)."
        fi
    else
        echo "⚠️ Could not determine EOL date for OpenSSL $MAJOR_MINOR. Proceeding cautiously."
    fi

    TARGET_REF="openssl-$VERSION"
    echo "🔍 Resolving Git SHA for tag '$TARGET_REF' in $TARGET_REPO..."
    SHA=$(git ls-remote --tags "https://github.com/$TARGET_REPO.git" "$TARGET_REF" | awk '{print $1}' | head -n 1)

    if [ -z "$SHA" ]; then
        echo "FATAL: Release tag '$TARGET_REF' not found in $TARGET_REPO!"
        exit 1
    fi

    ARTIFACT_VERSION="$VERSION"
    SLUGIFIED_VERSION="$VERSION"

else
    # Branch Mode
    if [[ "$VERSION" == */*/* ]]; then
        # Format: user/repo/branch
        TARGET_REPO=$(echo "$VERSION" | cut -d'/' -f1,2)
        TARGET_REF=$(echo "$VERSION" | cut -d'/' -f3-)
        IS_FORK="true"
    else
        TARGET_REF="$VERSION"
    fi

    echo "🔍 Resolving Git SHA for branch/ref '$TARGET_REF' in $TARGET_REPO..."
    SHA=$(git ls-remote "https://github.com/$TARGET_REPO.git" "$TARGET_REF" | awk '{print $1}' | head -n 1)

    if [ -z "$SHA" ]; then
        # Check if version is already a full 40-character commit SHA
        if [[ "$TARGET_REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
            SHA="$TARGET_REF"
        else
            echo "FATAL: Reference or branch '$TARGET_REF' does not exist in $TARGET_REPO!"
            exit 1
        fi
    fi

    TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
    SLUGIFIED_VERSION=$(echo "$VERSION" | sed 's/\//_/g')
    SAFE_PART=$(echo "$SLUGIFIED_VERSION" | cut -c 1-100)
    ARTIFACT_VERSION="${SAFE_PART}_${TIMESTAMP}"
fi

# 5. Stage version.txt for build-metadata
METADATA_DIR="${RUNNER_TEMP:-/tmp}/build-metadata"
mkdir -p "$METADATA_DIR"

if [ "$BUILD_TYPE" == "branch" ]; then
    echo "branch: $SLUGIFIED_VERSION" > "$METADATA_DIR/version.txt"
else
    echo "$SLUGIFIED_VERSION" > "$METADATA_DIR/version.txt"
fi
echo "✅ Staged version.txt for build-metadata: $(cat "$METADATA_DIR/version.txt")"

echo "================================================================"
echo " [VALIDATE-VERSION] Resolved SHA:        $SHA"
echo " [VALIDATE-VERSION] Target Ref:          $TARGET_REF"
echo " [VALIDATE-VERSION] Major.Minor:         $MAJOR_MINOR"
echo " [VALIDATE-VERSION] InnoSetup AppId:     $INNO_APP_ID"
echo " [VALIDATE-VERSION] Artifact Version:    $ARTIFACT_VERSION"
echo "================================================================"

# 5. Export selected flags for downstream step evaluation
{
  echo "build_windows=${BUILD_WINDOWS:-true}"
  echo "build_linux=${BUILD_LINUX:-true}"
  echo "build_macos=${BUILD_MACOS:-true}"
  echo "build_android=${BUILD_ANDROID:-true}"
  echo "build_ios=${BUILD_IOS:-true}"
  echo "sign_binaries=${SIGN_BINARIES:-false}"
  echo "build_installers=${BUILD_INSTALLERS:-false}"
} >> "$GITHUB_OUTPUT"

# 6. Output values to GITHUB_OUTPUT (or stdout if local)
{
    echo "version=$VERSION"
    echo "major_minor=$MAJOR_MINOR"
    echo "inno_app_id=$INNO_APP_ID"
    echo "target_repo=$TARGET_REPO"
    echo "is_fork=$IS_FORK"
    echo "ref=$TARGET_REF"
    echo "sha=$SHA"
    echo "artifact_version=$ARTIFACT_VERSION"
    echo "slugified_version=$SLUGIFIED_VERSION"
} >> "$GITHUB_OUTPUT"

# 7. Dynamic Matrix Catalog Generation

# 7.1. Full Platform Catalog for Compilation
ALL_COMPILE_TARGETS='[
  {"label": "Windows", "os": "windows-latest", "arch": "x64", "linkage": "shared", "target": "VC-WIN64A", "vcvars": "amd64"},
  {"label": "Windows", "os": "windows-latest", "arch": "x64", "linkage": "static", "target": "VC-WIN64A", "vcvars": "amd64"},
  {"label": "Windows", "os": "windows-latest", "arch": "x86", "linkage": "shared", "target": "VC-WIN32", "vcvars": "x86"},
  {"label": "Windows", "os": "windows-latest", "arch": "x86", "linkage": "static", "target": "VC-WIN32", "vcvars": "x86"},
  {"label": "Linux", "os": "ubuntu-latest", "arch": "x64", "linkage": "shared", "target": "linux-x86_64"},
  {"label": "Linux", "os": "ubuntu-latest", "arch": "x64", "linkage": "static", "target": "linux-x86_64"},
  {"label": "Linux", "os": "ubuntu-latest", "arch": "arm64", "linkage": "shared", "target": "linux-aarch64"},
  {"label": "Linux", "os": "ubuntu-latest", "arch": "arm64", "linkage": "static", "target": "linux-aarch64"},
  {"label": "macOS", "os": "macos-14", "arch": "x64", "linkage": "shared", "target": "darwin64-x86_64-cc", "minos": "10.14"},
  {"label": "macOS", "os": "macos-14", "arch": "x64", "linkage": "static", "target": "darwin64-x86_64-cc", "minos": "10.14"},
  {"label": "macOS", "os": "macos-14", "arch": "arm64", "linkage": "shared", "target": "darwin64-arm64-cc", "minos": "11.0"},
  {"label": "macOS", "os": "macos-14", "arch": "arm64", "linkage": "static", "target": "darwin64-arm64-cc", "minos": "11.0"},
  {"label": "Android", "os": "ubuntu-latest", "arch": "arm64", "linkage": "shared", "target": "android-arm64", "api": "21"},
  {"label": "Android", "os": "ubuntu-latest", "arch": "arm64", "linkage": "static", "target": "android-arm64", "api": "21"},
  {"label": "Android", "os": "ubuntu-latest", "arch": "arm", "linkage": "shared", "target": "android-arm", "api": "21"},
  {"label": "Android", "os": "ubuntu-latest", "arch": "arm", "linkage": "static", "target": "android-arm", "api": "21"},
  {"label": "iOS", "os": "macos-14", "arch": "arm64", "linkage": "static", "target": "ios64-cross"},
  {"label": "iOS", "os": "macos-14", "arch": "sim-arm64", "linkage": "static", "target": "iossimulator-xcrun", "minos": "11.0"}
]'

# 7.2. Full Platform Catalog for Packaging
ALL_PACKAGE_TARGETS='[
  {"label": "Windows", "arch": "x64", "runner": "ubuntu-latest"},
  {"label": "Windows", "arch": "x86", "runner": "ubuntu-latest"},
  {"label": "Windows", "arch": "arm64", "runner": "ubuntu-latest"},
  {"label": "Linux", "arch": "x64", "runner": "ubuntu-latest"},
  {"label": "Linux", "arch": "arm64", "runner": "ubuntu-latest"},
  {"label": "Android", "arch": "arm64", "runner": "ubuntu-latest"},
  {"label": "Android", "arch": "arm", "runner": "ubuntu-latest"},
  {"label": "macOS", "arch": "universal", "runner": "macos-14"},
  {"label": "iOS", "arch": "arm64", "runner": "macos-14"},
  {"label": "iOS", "arch": "sim-arm64", "runner": "macos-14"}
]'

# 7.3. Filter Enabled Platform Labels based on Inputs
SELECTED_LABELS=()
[ "${BUILD_WINDOWS:-true}" = "true" ] && SELECTED_LABELS+=("Windows")
[ "${BUILD_LINUX:-true}" = "true" ]   && SELECTED_LABELS+=("Linux")
[ "${BUILD_MACOS:-true}" = "true" ]   && SELECTED_LABELS+=("macOS")
[ "${BUILD_ANDROID:-true}" = "true" ] && SELECTED_LABELS+=("Android")
[ "${BUILD_IOS:-true}" = "true" ]     && SELECTED_LABELS+=("iOS")

if [ ${#SELECTED_LABELS[@]} -eq 0 ]; then
    echo "FATAL: At least one target platform must be selected!"
    exit 1
fi

LABELS_JSON=$(printf '%s\n' "${SELECTED_LABELS[@]}" | jq -R . | jq -s .)
COMPILE_MATRIX=$(echo "$ALL_COMPILE_TARGETS" | jq -c --argjson sel "$LABELS_JSON" '[.[] | select(.label as $l | $sel | index($l))]')
PACKAGE_MATRIX=$(echo "$ALL_PACKAGE_TARGETS" | jq -c --argjson sel "$LABELS_JSON" '[.[] | select(.label as $l | $sel | index($l))]')

echo "================================================================"
echo "                   WORKFLOW INPUTS SUMMARY                      "
echo "================================================================"
echo " Version:           $VERSION"
echo " Build Type:        $BUILD_TYPE"
echo " Sign Binaries:     ${SIGN_BINARIES:-false}"
echo " Build Installers:  ${BUILD_INSTALLERS:-false}"
echo " Ignore EOL:        $IGNORE_EOL"
echo " Keep Raw Artifacts:${KEEP_RAW_ARTIFACTS:-false}"
echo " Active Platforms:  ${SELECTED_LABELS[*]}"
echo " Active Matrix Jobs: $(echo "$COMPILE_MATRIX" | jq '. | length') compile job(s)"
echo "================================================================"

{
  echo "compile_matrix=$COMPILE_MATRIX"
  echo "package_matrix=$PACKAGE_MATRIX"
} >> "$GITHUB_OUTPUT"

exit 0
