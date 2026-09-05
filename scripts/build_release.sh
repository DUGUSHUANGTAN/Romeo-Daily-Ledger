#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/release}"
ARCHIVE_PATH="$BUILD_DIR/RomeoDailyLedger.xcarchive"
APP_NAME="Romeo Daily Ledger.app"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

command -v xcodegen >/dev/null || { echo "error: xcodegen is required" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "error: Xcode is required" >&2; exit 1; }
rm -rf "$ARCHIVE_PATH" "$BUILD_DIR/$APP_NAME"
mkdir -p "$BUILD_DIR"
cd "$ROOT_DIR"
xcodegen generate
archive_args=(
  archive -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger
  -configuration Release -destination 'generic/platform=macOS'
  -archivePath "$ARCHIVE_PATH"
  ARCHS=arm64 EXCLUDED_ARCHS=x86_64
)
if [[ -n "$SIGNING_IDENTITY" ]]; then
  archive_args+=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$SIGNING_IDENTITY")
else
  archive_args+=(CODE_SIGNING_ALLOWED=NO)
fi
xcodebuild "${archive_args[@]}"

APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME"
[[ -d "$APP_PATH" ]] || { echo "error: archived app not found at $APP_PATH" >&2; exit 1; }
if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --deep --force --verbose=2 --sign "$SIGNING_IDENTITY" "$APP_PATH"
else
  # Ad-hoc sign the archived bundle so its resources are sealed. Without this,
  # Gatekeeper can report the downloaded app as damaged.
  codesign --deep --force --verbose=2 --sign - "$APP_PATH"
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
ditto "$APP_PATH" "$BUILD_DIR/$APP_NAME"
codesign --verify --deep --strict --verbose=2 "$BUILD_DIR/$APP_NAME"
echo "$BUILD_DIR/$APP_NAME"
