#!/usr/bin/env bash
set -euo pipefail

APP_NAME="OTPilot"
APP_VERSION="${APP_VERSION:-1.5.1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
RELEASE_DIR="$DIST_DIR/releases"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$RELEASE_DIR/$APP_NAME-v$APP_VERSION.dmg"
VOLNAME="$APP_NAME"

BUILD_CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --build-app

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle: $APP_BUNDLE" >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$RELEASE_DIR"

/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
/usr/bin/hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "Created $DMG_PATH"
