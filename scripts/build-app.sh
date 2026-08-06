#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_DIR="$ROOT_DIR/dist/Other Mac.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

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

for resource_bundle in "$ROOT_DIR"/.build/release/*.bundle; do
  if [ -d "$resource_bundle" ]; then
    cp -R "$resource_bundle" "$RESOURCES_DIR/"
  fi
done

codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
