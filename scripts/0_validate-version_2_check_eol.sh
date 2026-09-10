#!/usr/bin/env bash
# =============================================================================
# scripts/0_validate-version_2_check_eol.sh
# Job: 0_validate-version | Step: 2 (Check EOL or Branch Existence)
# Resolves OpenSSL refs/SHAs, verifies EOL dates, and generates build identifiers.
# =============================================================================
set -euo pipefail

VERSION="${1:-${VERSION:-}}"
BUILD_TYPE="${2:-${BUILD_TYPE:-release}}"
IGNORE_EOL="${3:-${IGNORE_EOL:-false}}"

if [ -z "$VERSION" ]; then
  echo "ERROR: VERSION parameter or environment variable is required." >&2
  exit 1
fi

TARGET_REPO="openssl/openssl"
IS_FORK="false"

echo "[VALIDATE] Validating build inputs: Version='$VERSION', BuildType='$BUILD_TYPE', IgnoreEOL='$IGNORE_EOL'"

if [ "$BUILD_TYPE" == "release" ]; then
  MAJOR_MINOR=$(echo "$VERSION" | cut -d. -f1,2)
  EOL_DATE=$(curl -s https://raw.githubusercontent.com/openssl/release-metadata/refs/heads/main/data.json | jq -r ".[\"$MAJOR_MINOR\"].eol")
  EOL_DATE=$(echo "$EOL_DATE" | date -d "$EOL_DATE" +%s 2>/dev/null || date -d "01 $EOL_DATE" +%s 2>/dev/null || echo 0)

  if [ -z "$EOL_DATE" ] || [ "$EOL_DATE" == "null" ]; then
    echo "⚠️  Could not determine EOL date for $MAJOR_MINOR. Proceeding cautiously."
  else
    TODAY=$(date +%s)
    if [[ "$TODAY" > "$EOL_DATE" ]]; then
      echo "❌ OpenSSL $MAJOR_MINOR reached EOL on $(date -d "@$EOL_DATE" +%Y-%m-%d) ."
      if [ "$IGNORE_EOL" != "true" ]; then
        echo "Aborting build. Check 'Ignore EOL' to override." >&2
        exit 1
      fi
      echo "⚠️  Ignore EOL is checked. Proceeding anyway."
    fi
  fi
  TARGET_REF="openssl-$VERSION"

  echo "🔍 Resolving SHA for tag '$TARGET_REF' in $TARGET_REPO..."
  SHA=$(git ls-remote --tags "https://github.com/$TARGET_REPO.git" "$TARGET_REF" | awk '{print $1}')
  if [ -z "$SHA" ]; then
    echo "❌ Tag '$TARGET_REF' not found in $TARGET_REPO." >&2
    exit 1
  fi

  ARTIFACT_VERSION="$VERSION"
  SLUGIFIED_VERSION="$VERSION"
else
  # Branch / Fork Mode
  if [[ "$VERSION" == */*/* ]]; then
    # Format: user/repo/branch
    TARGET_REPO=$(echo "$VERSION" | cut -d'/' -f1,2)
    TARGET_REF=$(echo "$VERSION" | cut -d'/' -f3-)
    IS_FORK="true"
  else
    TARGET_REF="$VERSION"
  fi

  echo "🔍 Resolving SHA for branch/ref '$TARGET_REF' in repository '$TARGET_REPO'..."
  SHA=$(git ls-remote "https://github.com/$TARGET_REPO.git" "$TARGET_REF" | awk '{print $1}')

  if [ -z "$SHA" ]; then
    if [[ "$TARGET_REF" =~ ^[0-9a-f]{40}$ ]]; then
      SHA="$TARGET_REF"
    else
      echo "❌ Reference '$TARGET_REF' does not exist in $TARGET_REPO." >&2
      exit 1
    fi
  fi

  TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
  SLUGIFIED_VERSION=$(echo "$VERSION" | sed 's/\//_/g')
  SAFE_PART=$(echo "$SLUGIFIED_VERSION" | cut -c 1-100)
  ARTIFACT_VERSION="${SAFE_PART}_${TIMESTAMP}"
fi

MAJOR_MINOR=$(echo "$VERSION" | cut -d. -f1,2)

# Generate deterministic RFC 4122 UUIDv5 for InnoSetup AppId
INNO_APP_ID=$(python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_DNS, 'taurustls.openssl.inno.$MAJOR_MINOR'))" | tr '[:lower:]' '[:upper:]')

echo "[VALIDATE] Resolved Configuration:"
echo "  major_minor       = $MAJOR_MINOR"
echo "  inno_app_id       = $INNO_APP_ID"
echo "  target_repo       = $TARGET_REPO"
echo "  is_fork           = $IS_FORK"
echo "  ref               = $TARGET_REF"
echo "  sha               = $SHA"
echo "  artifact_version  = $ARTIFACT_VERSION"
echo "  slugified_version = $SLUGIFIED_VERSION"
echo "  version           = $VERSION"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "major_minor=$MAJOR_MINOR"
    echo "inno_app_id=$INNO_APP_ID"
    echo "target_repo=$TARGET_REPO"
    echo "is_fork=$IS_FORK"
    echo "ref=$TARGET_REF"
    echo "sha=$SHA"
    echo "artifact_version=$ARTIFACT_VERSION"
    echo "slugified_version=$SLUGIFIED_VERSION"
    echo "version=$VERSION"
  } >> "$GITHUB_OUTPUT"
fi
