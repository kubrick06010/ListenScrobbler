#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ListenScrobbler"
PROJECT="ListenScrobbler.xcodeproj"
SCHEME="ListenScrobbler"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/dist-derived"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"

xcodebuild build \
  -project "$ROOT_DIR/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED="$SIGNING_ALLOWED"

test -d "$APP_BUNDLE"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")"
ASSET_PATH="$DIST_DIR/$APP_NAME-$VERSION-macOS.zip"
TEMP_ASSET="$DIST_DIR/.$APP_NAME-$VERSION-macOS.zip.tmp"

mkdir -p "$DIST_DIR"
rm -f "$TEMP_ASSET"
trap 'rm -f "$TEMP_ASSET"' EXIT

ditto -c -k --keepParent "$APP_BUNDLE" "$TEMP_ASSET"
unzip -tq "$TEMP_ASSET"
mv -f "$TEMP_ASSET" "$ASSET_PATH"
trap - EXIT

ARCHITECTURES="$(lipo -archs "$APP_BUNDLE/Contents/MacOS/$APP_NAME")"
CHECKSUM="$(shasum -a 256 "$ASSET_PATH" | awk '{print $1}')"

printf 'Created: %s\n' "$ASSET_PATH"
printf 'Version: %s (%s)\n' "$VERSION" "$BUILD_NUMBER"
printf 'Architectures: %s\n' "$ARCHITECTURES"
printf 'SHA-256: %s\n' "$CHECKSUM"

if [[ "$SIGNING_ALLOWED" == "NO" ]]; then
  printf 'Signing: disabled (set CODE_SIGNING_ALLOWED=YES to use the configured signing identity)\n'
fi
