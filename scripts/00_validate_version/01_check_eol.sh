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

echo "================================================================"
echo " [VALIDATE-VERSION] Resolved SHA:        $SHA"
echo " [VALIDATE-VERSION] Target Ref:          $TARGET_REF"
echo " [VALIDATE-VERSION] Major.Minor:         $MAJOR_MINOR"
echo " [VALIDATE-VERSION] InnoSetup AppId:     $INNO_APP_ID"
echo " [VALIDATE-VERSION] Artifact Version:    $ARTIFACT_VERSION"
echo "================================================================"

# 5. Output values to GITHUB_OUTPUT (or stdout if local)
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

exit 0
