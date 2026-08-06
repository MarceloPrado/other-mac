#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$ROOT_DIR/dist/Other Mac.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
APP_VERSION=${APP_VERSION:-0.1.0}
BUILD_NUMBER=${BUILD_NUMBER:-1}
CODE_SIGN_IDENTITY=${CODE_SIGN_IDENTITY:--}

cd "$ROOT_DIR"
swift build -c release

if [ -d "$APP_DIR" ]; then
  rm -r "$APP_DIR"
fi
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/OtherMac" "$MACOS_DIR/OtherMac"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Sources/OtherMac/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Sources/OtherMac/Resources/m1ddc" "$RESOURCES_DIR/m1ddc"
cp "$ROOT_DIR/Sources/OtherMac/Resources/m1ddc-LICENSE.txt" "$RESOURCES_DIR/m1ddc-LICENSE.txt"
chmod 755 "$MACOS_DIR/OtherMac" "$RESOURCES_DIR/m1ddc"

/usr/bin/plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$CONTENTS_DIR/Info.plist"
/usr/bin/plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"

for resource_bundle in "$ROOT_DIR"/.build/release/*.bundle; do
  if [ -d "$resource_bundle" ]; then
    cp -R "$resource_bundle" "$APP_DIR/"
  fi
done

sign_item() {
  item=$1

  if [ "$CODE_SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - "$item"
  else
    codesign \
      --force \
      --options runtime \
      --timestamp \
      --sign "$CODE_SIGN_IDENTITY" \
      "$item"
  fi
}

sign_item "$RESOURCES_DIR/m1ddc"
sign_item "$MACOS_DIR/OtherMac"
sign_item "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "$APP_DIR"
