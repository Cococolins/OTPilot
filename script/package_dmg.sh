#!/usr/bin/env bash
set -euo pipefail

APP_NAME="OTPilot"
APP_VERSION="${APP_VERSION:-1.7.2}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
RELEASE_DIR="$DIST_DIR/releases"
STAGING_DIR="$DIST_DIR/dmg-staging"
BACKGROUND_SCRIPT="$DIST_DIR/dmg-background.py"
DMG_PATH="$RELEASE_DIR/$APP_NAME-v$APP_VERSION.dmg"
RW_DMG_PATH="$RELEASE_DIR/$APP_NAME-v$APP_VERSION-rw.dmg"
VOLNAME="$APP_NAME"

BUILD_ARCHS="${BUILD_ARCHS:-arm64 x86_64}" BUILD_CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --build-app

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle: $APP_BUNDLE" >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$RELEASE_DIR"

/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH" "$RW_DMG_PATH"
/usr/bin/hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$RW_DMG_PATH"

cat >"$BACKGROUND_SCRIPT" <<'PY'
#!/usr/bin/env python3
import math
import struct
import sys
import zlib

width, height = 600, 360
path = sys.argv[1]

def rgba(x, y):
    top = (250, 252, 255)
    bottom = (235, 242, 250)
    t = y / (height - 1)
    r = int(top[0] * (1 - t) + bottom[0] * t)
    g = int(top[1] * (1 - t) + bottom[1] * t)
    b = int(top[2] * (1 - t) + bottom[2] * t)

    # A subtle center highlight behind the drop area.
    dx = (x - width / 2) / 260
    dy = (y - height / 2) / 150
    glow = max(0, 1 - math.sqrt(dx * dx + dy * dy)) * 10
    r = min(255, int(r + glow))
    g = min(255, int(g + glow))
    b = min(255, int(b + glow))

    # Draw a restrained arrow from the app icon to Applications.
    ax0, ay0 = 235, 178
    ax1, ay1 = 365, 178
    distance_to_line = abs(y - ay0)
    on_line = ax0 <= x <= ax1 and distance_to_line <= 2
    head_upper = abs((y - ay1) - (-(x - ax1) * 0.65)) <= 2 and ax1 - 22 <= x <= ax1
    head_lower = abs((y - ay1) - ((x - ax1) * 0.65)) <= 2 and ax1 - 22 <= x <= ax1
    if on_line or head_upper or head_lower:
        return (118, 145, 174, 130)

    return (r, g, b, 255)

raw = bytearray()
for y in range(height):
    raw.append(0)
    for x in range(width):
        raw.extend(rgba(x, y))

def chunk(kind, data):
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    )

png = bytearray(b"\x89PNG\r\n\x1a\n")
png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
png.extend(chunk(b"IEND", b""))

with open(path, "wb") as f:
    f.write(png)
PY

MOUNT_DIR="$(mktemp -d /tmp/otpilot-dmg.XXXXXX)"
cleanup() {
  if /usr/sbin/diskutil info "$MOUNT_DIR" >/dev/null 2>&1; then
    /usr/bin/hdiutil detach "$MOUNT_DIR" -quiet || true
  fi
  rm -rf "$MOUNT_DIR" "$STAGING_DIR" "$BACKGROUND_SCRIPT" "$RW_DMG_PATH"
}
trap cleanup EXIT

/usr/bin/hdiutil attach "$RW_DMG_PATH" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

mkdir -p "$MOUNT_DIR/.background"
/usr/bin/python3 "$BACKGROUND_SCRIPT" "$MOUNT_DIR/.background/background.png"
/usr/bin/SetFile -a V "$MOUNT_DIR/.background" >/dev/null 2>&1 || /usr/bin/chflags hidden "$MOUNT_DIR/.background" || true

/usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to (POSIX file "$MOUNT_DIR") as alias
  open dmgFolder
  set dmgWindow to container window of dmgFolder
  set current view of dmgWindow to icon view
  set toolbar visible of dmgWindow to false
  set statusbar visible of dmgWindow to false
  set the bounds of dmgWindow to {100, 100, 700, 460}
  set viewOptions to the icon view options of dmgWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 96
  set background picture of viewOptions to (POSIX file "$MOUNT_DIR/.background/background.png")
  set position of item "$APP_NAME.app" of dmgFolder to {170, 185}
  set position of item "Applications" of dmgFolder to {430, 185}
  close dmgWindow
  open dmgFolder
  update dmgFolder without registering applications
  delay 1
end tell
APPLESCRIPT

/usr/bin/bless --folder "$MOUNT_DIR" --openfolder "$MOUNT_DIR" >/dev/null 2>&1 || true
/bin/sync
/usr/bin/hdiutil detach "$MOUNT_DIR" -quiet
rm -rf "$MOUNT_DIR"

/usr/bin/hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"

rm -rf "$STAGING_DIR" "$BACKGROUND_SCRIPT" "$RW_DMG_PATH"
trap - EXIT

echo "Created $DMG_PATH"
