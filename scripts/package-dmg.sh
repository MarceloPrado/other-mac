#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_VERSION=${APP_VERSION:-0.1.0}
BUILD_NUMBER=${BUILD_NUMBER:-1}
CODE_SIGN_IDENTITY=${CODE_SIGN_IDENTITY:--}
DMG_PATH="$ROOT_DIR/dist/Other-Mac.dmg"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/other-mac-dmg.XXXXXX")

cleanup() {
  rm -r "$STAGING_DIR"
}
trap cleanup EXIT HUP INT TERM

APP_VERSION="$APP_VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  sh "$ROOT_DIR/scripts/build-app.sh"

ditto "$ROOT_DIR/dist/Other Mac.app" "$STAGING_DIR/Other Mac.app"
ln -s /Applications "$STAGING_DIR/Applications"

if [ -f "$DMG_PATH" ]; then
  rm "$DMG_PATH"
fi

hdiutil create \
  -volname "Other Mac" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

if [ "$CODE_SIGN_IDENTITY" != "-" ]; then
  codesign \
    --force \
    --timestamp \
    --sign "$CODE_SIGN_IDENTITY" \
    "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

echo "$DMG_PATH"
