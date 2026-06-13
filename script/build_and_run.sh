#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="OTPilot"
BUNDLE_ID="${BUNDLE_ID:-app.otpilot.OTPilot}"
APP_VERSION="${APP_VERSION:-1.7.1}"
BUILD_NUMBER="${BUILD_NUMBER:-10}"
MIN_SYSTEM_VERSION="13.0"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
BUILD_ARCHS="${BUILD_ARCHS:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
INSTALL_BUNDLE="/Applications/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [[ "$BUILD_CONFIGURATION" == "release" && -n "$BUILD_ARCHS" ]]; then
  UNIVERSAL_BUILD_DIR="$DIST_DIR/universal-build"
  rm -rf "$UNIVERSAL_BUILD_DIR"
  mkdir -p "$UNIVERSAL_BUILD_DIR"

  BUILD_SLICES=()
  for arch in $BUILD_ARCHS; do
    case "$arch" in
      arm64)
        triple="arm64-apple-macosx$MIN_SYSTEM_VERSION"
        ;;
      x86_64)
        triple="x86_64-apple-macosx$MIN_SYSTEM_VERSION"
        ;;
      *)
        echo "Unsupported BUILD_ARCHS value: $arch" >&2
        exit 2
        ;;
    esac

    swift build -c release --triple "$triple"
    arch_bin="$(swift build -c release --triple "$triple" --show-bin-path)/$APP_NAME"
    BUILD_SLICES+=("$arch_bin")
  done

  BUILD_BINARY="$UNIVERSAL_BUILD_DIR/$APP_NAME"
  /usr/bin/lipo -create "${BUILD_SLICES[@]}" -output "$BUILD_BINARY"
elif [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  swift build -c release
  BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
else
  swift build
  BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
fi

if [[ -f "$ROOT_DIR/Resources/AppPanelIcon.png" ]]; then
  cp "$ROOT_DIR/Resources/AppPanelIcon.png" "$APP_RESOURCES/AppPanelIcon.png"
fi

if [[ -f "$ROOT_DIR/Resources/AppStatusBarIconTemplate.png" ]]; then
  cp "$ROOT_DIR/Resources/AppStatusBarIconTemplate.png" "$APP_RESOURCES/AppStatusBarIconTemplate.png"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$APP_BUNDLE"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development: .*\)".*/\1/p' \
    | head -n 1)"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

echo "Signing $APP_NAME with: $SIGN_IDENTITY"
/usr/bin/codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

install_app() {
  rm -rf "$INSTALL_BUNDLE"
  /usr/bin/ditto "$APP_BUNDLE" "$INSTALL_BUNDLE"
  /usr/bin/open -n "$INSTALL_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --install|install)
    install_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --build-app|build-app)
    echo "Built $APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--install|--debug|--logs|--telemetry|--verify|--build-app]" >&2
    exit 2
    ;;
esac
