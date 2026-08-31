#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/release}"
VERSION="${VERSION:-1.0.1}"
APP_NAME="Romeo Daily Ledger.app"
DMG_NAME="Romeo-Daily-Ledger-$VERSION.dmg"
STAGING_DIR="$BUILD_DIR/dmg-root"

[[ "${SKIP_BUILD:-0}" == "1" ]] || BUILD_DIR="$BUILD_DIR" "$ROOT_DIR/scripts/build_release.sh"
APP_PATH="$BUILD_DIR/$APP_NAME"
[[ -d "$APP_PATH" ]] || { echo "error: app not found at $APP_PATH" >&2; exit 1; }
rm -rf "$STAGING_DIR" "$BUILD_DIR/$DMG_NAME" "$BUILD_DIR/$DMG_NAME.sha256"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "Romeo Daily Ledger" -srcfolder "$STAGING_DIR" \
  -ov -format UDZO "$BUILD_DIR/$DMG_NAME"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$BUILD_DIR/$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$BUILD_DIR/$DMG_NAME"
fi
(cd "$BUILD_DIR" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")
rm -rf "$STAGING_DIR"
echo "$BUILD_DIR/$DMG_NAME"
echo "$BUILD_DIR/$DMG_NAME.sha256"
