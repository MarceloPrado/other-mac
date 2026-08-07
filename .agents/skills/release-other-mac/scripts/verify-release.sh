#!/bin/sh

set -eu

EXPECTED_REPO="MarceloPrado/other-mac"
VERSION=${1:-}
EXPECTED_SHA=${2:-}

fail() {
  echo "verify-release: $*" >&2
  exit 1
}

case "$VERSION" in
  ""|*[!0-9.]*|.*|*.|*..*)
    fail "usage: $0 X.Y.Z [expected-commit-sha]"
    ;;
esac

PART_COUNT=$(printf '%s' "$VERSION" | awk -F. '{ print NF }')
test "$PART_COUNT" -eq 3 ||
  fail "version must be a stable X.Y.Z value"

TAG="v$VERSION"
ARCHIVE_NAME="Other-Mac-$VERSION.zip"
LATEST_APPCAST_URL="https://github.com/$EXPECTED_REPO/releases/latest/download/appcast.xml"

command -v gh >/dev/null 2>&1 || fail "GitHub CLI is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v ruby >/dev/null 2>&1 || fail "Ruby is required"
command -v rg >/dev/null 2>&1 || fail "ripgrep is required"
command -v unzip >/dev/null 2>&1 || fail "unzip is required"
command -v ditto >/dev/null 2>&1 || fail "ditto is required"
command -v hdiutil >/dev/null 2>&1 || fail "hdiutil is required"

ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null) ||
  fail "run this script inside the Other Mac repository"
cd "$ROOT_DIR"

IS_DRAFT=$(gh release view "$TAG" --repo "$EXPECTED_REPO" \
  --json isDraft --jq .isDraft)
IS_PRERELEASE=$(gh release view "$TAG" --repo "$EXPECTED_REPO" \
  --json isPrerelease --jq .isPrerelease)
test "$IS_DRAFT" = "false" || fail "$TAG is still a draft"
test "$IS_PRERELEASE" = "false" || fail "$TAG is unexpectedly a prerelease"

LATEST_TAG=$(gh release view --repo "$EXPECTED_REPO" --json tagName --jq .tagName)
test "$LATEST_TAG" = "$TAG" ||
  fail "latest public release is $LATEST_TAG, not $TAG"

if test -n "$EXPECTED_SHA"; then
  RELEASE_TARGET=$(gh release view "$TAG" --repo "$EXPECTED_REPO" \
    --json targetCommitish --jq .targetCommitish)
  test "$RELEASE_TARGET" = "$EXPECTED_SHA" ||
    fail "$TAG targets $RELEASE_TARGET instead of $EXPECTED_SHA"
fi

ASSETS=$(gh release view "$TAG" --repo "$EXPECTED_REPO" \
  --json assets --jq '.assets[].name')
printf '%s\n' "$ASSETS" | rg -qx 'Other-Mac.dmg' ||
  fail "Other-Mac.dmg is missing"
printf '%s\n' "$ASSETS" | rg -qx "$ARCHIVE_NAME" ||
  fail "$ARCHIVE_NAME is missing"
printf '%s\n' "$ASSETS" | rg -qx 'appcast.xml' ||
  fail "appcast.xml is missing"

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/other-mac-release.XXXXXX")
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

gh release download "$TAG" \
  --repo "$EXPECTED_REPO" \
  --pattern 'Other-Mac.dmg' \
  --pattern "$ARCHIVE_NAME" \
  --pattern 'appcast.xml' \
  --dir "$TEMP_DIR"

ATTEMPT=1
while :
do
  curl --fail --silent --show-error --location \
    "$LATEST_APPCAST_URL" \
    --output "$TEMP_DIR/latest-appcast.xml"
  if cmp -s "$TEMP_DIR/appcast.xml" "$TEMP_DIR/latest-appcast.xml"; then
    break
  fi
  test "$ATTEMPT" -lt 6 ||
    fail "the public latest appcast does not match the release asset"
  ATTEMPT=$((ATTEMPT + 1))
  sleep 5
done

APPCAST_PATH="$TEMP_DIR/appcast.xml" RELEASE_VERSION="$VERSION" ruby <<'RUBY'
require "rexml/document"

path = ENV.fetch("APPCAST_PATH")
version = ENV.fetch("RELEASE_VERSION")
document = REXML::Document.new(File.read(path))
item = document.elements["rss/channel/item"] or raise "appcast item is missing"
enclosure = item.elements["enclosure"] or raise "appcast enclosure is missing"

expected_url =
  "https://github.com/MarceloPrado/other-mac/releases/download/v#{version}/Other-Mac-#{version}.zip"

raise "short version mismatch" unless enclosure.attributes["sparkle:shortVersionString"] == version
raise "build version mismatch" unless enclosure.attributes["sparkle:version"] == version
raise "updater archive URL mismatch" unless enclosure.attributes["url"] == expected_url
raise "EdDSA signature is missing" if enclosure.attributes["sparkle:edSignature"].to_s.empty?
raise "archive length is missing" if enclosure.attributes["length"].to_s.empty?

description = item.elements["description"] or raise "release description is missing"
raise "release notes are not Markdown" unless description.attributes["sparkle:format"] == "markdown"
raise "release notes are empty" if description.text.to_s.strip.empty?
RUBY

unzip -t "$TEMP_DIR/$ARCHIVE_NAME" >/dev/null
mkdir "$TEMP_DIR/unpacked"
ditto -x -k "$TEMP_DIR/$ARCHIVE_NAME" "$TEMP_DIR/unpacked"
sh scripts/verify-app.sh "$TEMP_DIR/unpacked/Other Mac.app" "$VERSION"
hdiutil verify "$TEMP_DIR/Other-Mac.dmg" >/dev/null

RELEASE_URL=$(gh release view "$TAG" --repo "$EXPECTED_REPO" \
  --json url --jq .url)
echo "verify-release: $TAG passed"
echo "verify-release: $RELEASE_URL"
