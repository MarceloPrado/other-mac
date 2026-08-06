#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 path/to/Other-Mac.dmg" >&2
  exit 64
fi

DMG_PATH=$1

if [ ! -f "$DMG_PATH" ]; then
  echo "DMG not found: $DMG_PATH" >&2
  exit 66
fi

if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
  xcrun notarytool submit \
    "$DMG_PATH" \
    --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
    --wait
else
  : "${APPLE_ID:?Set APPLE_ID to the Apple Developer account email.}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to the Developer Team ID.}"
  : "${APPLE_APP_PASSWORD:?Set APPLE_APP_PASSWORD to an app-specific password.}"

  xcrun notarytool submit \
    "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
fi

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl \
  --assess \
  --type open \
  --context context:primary-signature \
  --verbose=2 \
  "$DMG_PATH"
