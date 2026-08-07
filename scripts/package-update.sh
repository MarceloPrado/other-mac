#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_VERSION=${APP_VERSION:-0.1.0}
SPARKLE_ACCOUNT=${SPARKLE_ACCOUNT:-com.marceloprado.othermac}
SPARKLE_PRIVATE_KEY=${SPARKLE_PRIVATE_KEY:-}
SPARKLE_TOOLS_DIR=${SPARKLE_TOOLS_DIR:-"$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"}
GENERATE_APPCAST="$SPARKLE_TOOLS_DIR/generate_appcast"
APP_PATH="$ROOT_DIR/dist/Other Mac.app"
ARCHIVE_NAME="Other-Mac-$APP_VERSION.zip"
ARCHIVE_PATH="$ROOT_DIR/dist/$ARCHIVE_NAME"
APPCAST_PATH="$ROOT_DIR/dist/appcast.xml"
RELEASE_NOTES_PATH=${RELEASE_NOTES_PATH:-"$ROOT_DIR/dist/release-notes.md"}
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/other-mac-update.XXXXXX")

cleanup() {
  rm -r "$STAGING_DIR"
}
trap cleanup EXIT HUP INT TERM

test -d "$APP_PATH"
test -x "$GENERATE_APPCAST"

ditto \
  -c \
  -k \
  --sequesterRsrc \
  --keepParent \
  "$APP_PATH" \
  "$STAGING_DIR/$ARCHIVE_NAME"

if [ -s "$RELEASE_NOTES_PATH" ]; then
  cp "$RELEASE_NOTES_PATH" "$STAGING_DIR/Other-Mac-$APP_VERSION.md"
fi

if [ -n "$SPARKLE_PRIVATE_KEY" ]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" |
    "$GENERATE_APPCAST" \
      --ed-key-file - \
      --download-url-prefix \
      "https://github.com/MarceloPrado/other-mac/releases/download/v$APP_VERSION/" \
      --full-release-notes-url \
      "https://github.com/MarceloPrado/other-mac/releases/tag/v$APP_VERSION" \
      --embed-release-notes \
      --link "https://github.com/MarceloPrado/other-mac" \
      --maximum-versions 1 \
      --maximum-deltas 0 \
      -o "$STAGING_DIR/appcast.xml" \
      "$STAGING_DIR"
else
  "$GENERATE_APPCAST" \
    --account "$SPARKLE_ACCOUNT" \
    --download-url-prefix \
    "https://github.com/MarceloPrado/other-mac/releases/download/v$APP_VERSION/" \
    --full-release-notes-url \
    "https://github.com/MarceloPrado/other-mac/releases/tag/v$APP_VERSION" \
    --embed-release-notes \
    --link "https://github.com/MarceloPrado/other-mac" \
    --maximum-versions 1 \
    --maximum-deltas 0 \
    -o "$STAGING_DIR/appcast.xml" \
    "$STAGING_DIR"
fi

mv "$STAGING_DIR/$ARCHIVE_NAME" "$ARCHIVE_PATH"
mv "$STAGING_DIR/appcast.xml" "$APPCAST_PATH"

test -s "$ARCHIVE_PATH"
test -s "$APPCAST_PATH"
grep -q 'sparkle:edSignature=' "$APPCAST_PATH"
grep -q "v$APP_VERSION/$ARCHIVE_NAME" "$APPCAST_PATH"

echo "$ARCHIVE_PATH"
echo "$APPCAST_PATH"
