#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_VERSION=${APP_VERSION:-0.1.0}
BUILD_NUMBER=${BUILD_NUMBER:-1}
CODE_SIGN_IDENTITY=${CODE_SIGN_IDENTITY:--}
DMG_PATH="$ROOT_DIR/dist/Other-Mac.dmg"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/other-mac-dmg.XXXXXX")
CREATE_DMG_BIN=${CREATE_DMG_BIN:-}

cleanup() {
  rm -r "$STAGING_DIR"
}
trap cleanup EXIT HUP INT TERM

if [ -z "$CREATE_DMG_BIN" ]; then
  CREATE_DMG_BIN=$(command -v create-dmg || true)
fi

if [ -z "$CREATE_DMG_BIN" ]; then
  echo "create-dmg is required. Install it with: brew install create-dmg" >&2
  exit 69
fi

APP_VERSION="$APP_VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  sh "$ROOT_DIR/scripts/build-app.sh"

ditto "$ROOT_DIR/dist/Other Mac.app" "$STAGING_DIR/Other Mac.app"

if [ -f "$DMG_PATH" ]; then
  rm "$DMG_PATH"
fi

"$CREATE_DMG_BIN" \
  --volname "Other Mac" \
  --volicon "$ROOT_DIR/Sources/OtherMac/Resources/AppIcon.icns" \
  --background "$ROOT_DIR/Resources/dmg-background.png" \
  --window-pos 200 120 \
  --window-size 660 420 \
  --text-size 13 \
  --icon-size 112 \
  --icon "Other Mac.app" 165 215 \
  --hide-extension "Other Mac.app" \
  --app-drop-link 495 215 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$STAGING_DIR"

if [ "$CODE_SIGN_IDENTITY" != "-" ]; then
  codesign \
    --force \
    --timestamp \
    --sign "$CODE_SIGN_IDENTITY" \
    "$DMG_PATH"
else
  codesign --force --sign - "$DMG_PATH"
fi

codesign --verify --verbose=2 "$DMG_PATH"
echo "$DMG_PATH"
