#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_PATH=${1:-"$ROOT_DIR/dist/Other Mac.app"}
EXPECTED_VERSION=${2:-}
CONTENTS_DIR="$APP_PATH/Contents"

test -x "$CONTENTS_DIR/MacOS/OtherMac"
test -x "$CONTENTS_DIR/Resources/m1ddc"
test -f "$CONTENTS_DIR/Resources/AppIcon.icns"
test -f "$CONTENTS_DIR/Resources/m1ddc-LICENSE.txt"
test ! -e "$APP_PATH/OtherMac_OtherMac.bundle"
test ! -e "$APP_PATH/KeyboardShortcuts_KeyboardShortcuts.bundle"

test "$(plutil -extract CFBundleIdentifier raw "$CONTENTS_DIR/Info.plist")" \
  = "com.marceloprado.othermac"
test "$(plutil -extract LSUIElement raw "$CONTENTS_DIR/Info.plist")" = "true"

if [ -n "$EXPECTED_VERSION" ]; then
  test "$(plutil -extract CFBundleShortVersionString raw "$CONTENTS_DIR/Info.plist")" \
    = "$EXPECTED_VERSION"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --verify --strict --verbose=2 "$CONTENTS_DIR/MacOS/OtherMac"
codesign --verify --strict --verbose=2 "$CONTENTS_DIR/Resources/m1ddc"

echo "PASS: app resources, metadata, sealed resources, and signatures"
