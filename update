#!/usr/bin/env nix-shell
#! nix-shell -p curl jq -i bash
set -e

# Base URL for Claude Code releases
BASE_URL="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Fetch the stable version
echo "Fetching latest stable version..."
VERSION=$(curl -s "${BASE_URL}/stable")
echo "Found version: $VERSION"

# Fetch the manifest.json for this version
echo "Fetching manifest for version $VERSION..."
MANIFEST=$(curl -s "${BASE_URL}/${VERSION}/manifest.json")

# Extract SHA256 hashes for each platform
SHA256_LINUX_X64=$(echo "$MANIFEST" | jq -r '.platforms["linux-x64"].checksum')
SHA256_LINUX_ARM64=$(echo "$MANIFEST" | jq -r '.platforms["linux-arm64"].checksum')
SHA256_DARWIN_X64=$(echo "$MANIFEST" | jq -r '.platforms["darwin-x64"].checksum')
SHA256_DARWIN_ARM64=$(echo "$MANIFEST" | jq -r '.platforms["darwin-arm64"].checksum')

echo "Linux x64 SHA256: $SHA256_LINUX_X64"
echo "Linux arm64 SHA256: $SHA256_LINUX_ARM64"
echo "Darwin x64 SHA256: $SHA256_DARWIN_X64"
echo "Darwin arm64 SHA256: $SHA256_DARWIN_ARM64"

# Build URLs
URL_LINUX_X64="${BASE_URL}/${VERSION}/linux-x64/claude"
URL_LINUX_ARM64="${BASE_URL}/${VERSION}/linux-arm64/claude"
URL_DARWIN_X64="${BASE_URL}/${VERSION}/darwin-x64/claude"
URL_DARWIN_ARM64="${BASE_URL}/${VERSION}/darwin-arm64/claude"

# Create new sources.json entry
NEW_ENTRY=$(jq -n \
  --arg version "$VERSION" \
  --arg url_linux_x64 "$URL_LINUX_X64" \
  --arg sha256_linux_x64 "$SHA256_LINUX_X64" \
  --arg url_linux_arm64 "$URL_LINUX_ARM64" \
  --arg sha256_linux_arm64 "$SHA256_LINUX_ARM64" \
  --arg url_darwin_x64 "$URL_DARWIN_X64" \
  --arg sha256_darwin_x64 "$SHA256_DARWIN_X64" \
  --arg url_darwin_arm64 "$URL_DARWIN_ARM64" \
  --arg sha256_darwin_arm64 "$SHA256_DARWIN_ARM64" \
  '{
    ($version): {
      "x86_64-linux": {
        "url": $url_linux_x64,
        "version": $version,
        "sha256": $sha256_linux_x64
      },
      "aarch64-linux": {
        "url": $url_linux_arm64,
        "version": $version,
        "sha256": $sha256_linux_arm64
      },
      "x86_64-darwin": {
        "url": $url_darwin_x64,
        "version": $version,
        "sha256": $sha256_darwin_x64
      },
      "aarch64-darwin": {
        "url": $url_darwin_arm64,
        "version": $version,
        "sha256": $sha256_darwin_arm64
      }
    }
  }')

# Copy the old file as backup
cp sources.json sources.old.json

# Merge with existing sources.json
jq -s '.[0] * .[1]' sources.old.json <(echo "$NEW_ENTRY") > sources.json

echo "Updated sources.json with version $VERSION"
