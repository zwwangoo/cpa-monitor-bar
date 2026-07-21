#!/usr/bin/env bash
# Creates and validates a compressed macOS DMG from an already signed app.

set -Eeuo pipefail

APP="${1:-}"
TESTING_NOTES="${2:-}"
DMG="${3:-}"
EXPECTED_VERSION="${4:-}"
PRODUCT="CPAMonitorBar"
VOLUME_NAME="CPA Monitor Bar"
STAGING="$(mktemp -d /tmp/cpa-monitor-bar-dmg-stage.XXXXXX)"
MOUNT_POINT="$(mktemp -d /tmp/cpa-monitor-bar-dmg-mount.XXXXXX)"
MOUNTED=0

cleanup() {
  if [[ "$MOUNTED" == "1" ]]; then
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGING" "$MOUNT_POINT"
}
trap cleanup EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -d "$APP" ]] || fail "App bundle not found: $APP"
[[ -f "$TESTING_NOTES" ]] || fail "Testing notes not found: $TESTING_NOTES"
[[ -n "$DMG" ]] || fail "DMG output path is required"
[[ ! -e "$DMG" ]] || fail "DMG output already exists: $DMG"
mkdir -p "$(dirname "$DMG")"

echo "==> Preparing DMG layout..."
ditto "$APP" "$STAGING/$PRODUCT.app"
cp "$TESTING_NOTES" "$STAGING/TESTING.md"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating compressed DMG..."
hdiutil create \
  -srcfolder "$STAGING" \
  -volname "$VOLUME_NAME" \
  -format UDZO \
  "$DMG"

echo "==> Verifying DMG container..."
hdiutil verify "$DMG"

echo "==> Mounting DMG read-only for payload validation..."
hdiutil attach \
  -readonly \
  -nobrowse \
  -mountpoint "$MOUNT_POINT" \
  "$DMG"
MOUNTED=1

MOUNTED_APP="$MOUNT_POINT/$PRODUCT.app"
MOUNTED_EXE="$MOUNTED_APP/Contents/MacOS/$PRODUCT"
[[ -x "$MOUNTED_EXE" ]] || fail "Mounted app executable is missing"
[[ -L "$MOUNT_POINT/Applications" ]] || fail "Applications shortcut is missing"
[[ "$(readlink "$MOUNT_POINT/Applications")" == "/Applications" ]] \
  || fail "Applications shortcut target is invalid"
[[ -f "$MOUNTED_APP/Contents/Resources/AppIcon.icns" ]] \
  || fail "Mounted app icon is missing"

lipo -info "$MOUNTED_EXE"
codesign --verify --deep --strict --verbose=4 "$MOUNTED_APP"
plutil -lint "$MOUNTED_APP/Contents/Info.plist"
if [[ -n "$EXPECTED_VERSION" ]]; then
  [[ "$(plutil -extract CFBundleShortVersionString raw "$MOUNTED_APP/Contents/Info.plist")" \
    == "$EXPECTED_VERSION" ]] || fail "Mounted app version does not match: $EXPECTED_VERSION"
fi

set +e
rg -a -q \
  -e 'CPA_PWD' \
  -e 'cpa_usage_keeper_session' \
  -e '\.env' \
  "$MOUNTED_APP"
SCAN_STATUS=$?
set -e
[[ "$SCAN_STATUS" == "1" ]] || {
  [[ "$SCAN_STATUS" == "0" ]] && fail "Credential marker found in mounted app"
  fail "Credential marker scan failed with status $SCAN_STATUS"
}
echo "dmg_payload_validation=ok"
echo "credential_markers=absent"

hdiutil detach "$MOUNT_POINT"
MOUNTED=0
echo "DMG: $DMG"
echo "SHA-256:"
shasum -a 256 "$DMG"
