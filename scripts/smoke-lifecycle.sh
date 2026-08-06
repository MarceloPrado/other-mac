#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_PATH=${1:-"$ROOT_DIR/dist/Other Mac.app"}
PREFERENCES=${2:-clean}
ITERATIONS=${OTHER_MAC_SMOKE_ITERATIONS:-20}
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/other-mac-lifecycle.XXXXXX")
SUPPORT_DIR="$TEMP_DIR/Application Support"
RESULT_PATH="$TEMP_DIR/result.txt"
LOG_PATH="$TEMP_DIR/app.log"
APP_PID=

cleanup() {
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  rm -r "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

case "$PREFERENCES" in
  clean)
    mkdir -p "$SUPPORT_DIR"
    ;;
  legacy)
    mkdir -p "$SUPPORT_DIR/zap-source-switcher"
    cp "$ROOT_DIR/Tests/Fixtures/legacy-v0.1.0-settings.json" \
      "$SUPPORT_DIR/zap-source-switcher/settings.json"
    ;;
  *)
    echo "Preferences must be 'clean' or 'legacy'." >&2
    exit 64
    ;;
esac

if [ "$PREFERENCES" = "legacy" ]; then
  OTHER_MAC_APPLICATION_SUPPORT_DIRECTORY="$SUPPORT_DIR" \
  OTHER_MAC_LIFECYCLE_SMOKE_RESULT="$RESULT_PATH" \
  OTHER_MAC_LIFECYCLE_SMOKE_ITERATIONS="$ITERATIONS" \
    "$APP_PATH/Contents/MacOS/OtherMac" \
    -KeyboardShortcuts_swapToOtherMac \
    '"{\"carbonModifiers\":2048,\"carbonKeyCode\":49}"' \
    >"$LOG_PATH" 2>&1 &
else
  OTHER_MAC_APPLICATION_SUPPORT_DIRECTORY="$SUPPORT_DIR" \
  OTHER_MAC_LIFECYCLE_SMOKE_RESULT="$RESULT_PATH" \
  OTHER_MAC_LIFECYCLE_SMOKE_ITERATIONS="$ITERATIONS" \
    "$APP_PATH/Contents/MacOS/OtherMac" >"$LOG_PATH" 2>&1 &
fi
APP_PID=$!

attempt=0
while [ "$attempt" -lt 300 ] && [ ! -f "$RESULT_PATH" ]; do
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "FAIL: packaged app terminated before the smoke test completed." >&2
    cat "$LOG_PATH" >&2
    exit 1
  fi
  sleep 0.1
  attempt=$((attempt + 1))
done

if [ ! -f "$RESULT_PATH" ]; then
  echo "FAIL: lifecycle smoke test timed out." >&2
  cat "$LOG_PATH" >&2
  exit 1
fi

RESULT=$(cat "$RESULT_PATH")
case "$RESULT" in
  PASS:*) ;;
  *)
    echo "$RESULT" >&2
    cat "$LOG_PATH" >&2
    exit 1
    ;;
esac

sleep 0.5
if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "FAIL: packaged app terminated after the smoke test completed." >&2
  cat "$LOG_PATH" >&2
  exit 1
fi

if [ "$PREFERENCES" = "legacy" ]; then
  MIGRATED_PATH="$SUPPORT_DIR/Other Mac/settings.json"
  test -f "$MIGRATED_PATH"
  test "$(plutil -extract version raw "$MIGRATED_PATH")" = "3"
  test "$(plutil -extract completedOnboarding raw "$MIGRATED_PATH")" = "true"
fi

echo "$RESULT ($PREFERENCES preferences)"
