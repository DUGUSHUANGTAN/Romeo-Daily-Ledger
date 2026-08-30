#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/release}"
ARCHIVE_PATH="$BUILD_DIR/RomeoDailyLedger.xcarchive"
APP_NAME="Romeo Daily Ledger.app"

command -v xcodegen >/dev/null || { echo "error: xcodegen is required" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "error: Xcode is required" >&2; exit 1; }
rm -rf "$ARCHIVE_PATH" "$BUILD_DIR/$APP_NAME"
mkdir -p "$BUILD_DIR"
cd "$ROOT_DIR"
xcodegen generate
xcodebuild archive -project RomeoDailyLedger.xcodeproj -scheme RomeoDailyLedger \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" CODE_SIGNING_ALLOWED=NO

APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME"
[[ -d "$APP_PATH" ]] || { echo "error: archived app not found at $APP_PATH" >&2; exit 1; }
ditto "$APP_PATH" "$BUILD_DIR/$APP_NAME"
echo "$BUILD_DIR/$APP_NAME"
