#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

swift test
sh scripts/build-app.sh

echo "Detected displays:"
"$ROOT_DIR/Sources/OtherMac/Resources/m1ddc" display list

echo "Opening Other Mac…"
open "$ROOT_DIR/dist/Other Mac.app"
