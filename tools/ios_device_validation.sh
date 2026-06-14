#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_ID="${DEVICE_ID:-A04FE658-891B-575D-A47B-26424DACB600}"
DEVICE_DESTINATION="${DEVICE_DESTINATION:-platform=iOS,id=00008120-0004388834C3601E}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
BUNDLE_ID="${BUNDLE_ID:-org.listenscrobbler.app.ios}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/tmp/ios-device-derived}"
TRACE_DIR="${TRACE_DIR:-$ROOT_DIR/tmp/device-traces}"

cd "$ROOT_DIR"
mkdir -p "$TRACE_DIR"

echo "== Device =="
xcrun devicectl list devices | rg -n "Name:|Identifier:|State:|Model:" || true

echo
echo "== Installed ListenScrobbler app, before install =="
xcrun devicectl device info apps \
  --device "$DEVICE_ID" \
  --bundle-id "$BUNDLE_ID" || true

echo
echo "== Build signed iOS app =="
BUILD_ARGS=(
  -project ListenScrobbler.xcodeproj
  -scheme ListenScrobbleriOS
  -destination "$DEVICE_DESTINATION"
  -derivedDataPath "$DERIVED_DATA"
  CODE_SIGN_STYLE=Automatic
  -allowProvisioningUpdates
)
if [[ -n "$DEVELOPMENT_TEAM" ]]; then
  BUILD_ARGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
fi
xcodebuild build "${BUILD_ARGS[@]}"

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/ListenScrobbler.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app not found at: $APP_PATH" >&2
  exit 1
fi

echo
echo "== Install app =="
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  "$APP_PATH"

echo
echo "== Installed ListenScrobbler app, after install =="
xcrun devicectl device info apps \
  --device "$DEVICE_ID" \
  --bundle-id "$BUNDLE_ID"

echo
echo "== Launch app =="
xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  "$BUNDLE_ID"

echo
echo "== Optional trace command =="
echo "Run this while exercising connect, refresh, and Music library scan:"
echo "xcrun xctrace record --template 'Time Profiler' --device 00008120-0004388834C3601E --attach ListenScrobbler --time-limit 30s --output '$TRACE_DIR/ListenScrobbler-current-device.trace' --no-prompt"
