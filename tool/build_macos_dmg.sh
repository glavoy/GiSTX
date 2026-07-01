#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
BUILD_DIR="$PROJECT_ROOT/build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/gistx.app"
OUTPUT_DIR="${1:-"$PROJECT_ROOT/installer_output"}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: macOS and Xcode are required to build a DMG." >&2
  exit 1
fi

for command in flutter hdiutil ditto; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Error: required command '$command' was not found." >&2
    exit 1
  fi
done

VERSION="$(awk '/^version:[[:space:]]*/ { print $2; exit }' "$PUBSPEC")"
if [[ -z "$VERSION" ]]; then
  echo "Error: no version was found in pubspec.yaml." >&2
  exit 1
fi

# Build metadata after "+" is useful internally but is omitted from the
# user-facing installer filename.
VERSION_NAME="${VERSION%%+*}"
DMG_NAME="GiSTX-${VERSION_NAME}.dmg"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gistx-dmg.XXXXXX")"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "Building GiSTX $VERSION for macOS..."
cd "$PROJECT_ROOT"
flutter build macos --release

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: expected app bundle was not found at $APP_PATH." >&2
  exit 1
fi

echo "Preparing disk image..."
ditto "$APP_PATH" "$STAGING_DIR/GiSTX.app"
ln -s /Applications "$STAGING_DIR/Applications"

if ! codesign -dv --verbose=2 "$APP_PATH" 2>&1 |
    grep -q "Authority=Developer ID Application"; then
  echo "Note: this app is not Developer ID signed or notarized."
  echo "Recipients may need to Control-click GiSTX and choose Open on first launch."
fi

hdiutil create \
  -volname "GiSTX $VERSION_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"

echo
echo "Created: $DMG_PATH"
