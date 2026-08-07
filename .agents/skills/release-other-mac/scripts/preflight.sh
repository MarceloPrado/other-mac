#!/bin/sh

set -eu

EXPECTED_REPO="MarceloPrado/other-mac"

fail() {
  echo "preflight: $*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v gh >/dev/null 2>&1 || fail "GitHub CLI is required"
command -v rg >/dev/null 2>&1 || fail "ripgrep is required"
command -v ruby >/dev/null 2>&1 || fail "Ruby is required"
command -v swift >/dev/null 2>&1 || fail "Swift is required"

ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null) ||
  fail "run this script inside the Other Mac repository"
cd "$ROOT_DIR"

test -f Package.swift || fail "Package.swift is missing"
test -f .github/workflows/release.yml || fail "release workflow is missing"
test -f scripts/package-update.sh || fail "Sparkle packaging script is missing"
test -f Resources/Info.plist || fail "Info.plist is missing"

CURRENT_BRANCH=$(git branch --show-current)
test "$CURRENT_BRANCH" = "main" ||
  fail "releases must run from main (currently $CURRENT_BRANCH)"

UNMERGED=$(git diff --name-only --diff-filter=U)
test -z "$UNMERGED" || fail "resolve unmerged paths before releasing"

for marker in \
  MERGE_HEAD \
  CHERRY_PICK_HEAD \
  REVERT_HEAD \
  rebase-merge \
  rebase-apply
do
  MARKER_PATH=$(git rev-parse --git-path "$marker")
  test ! -e "$MARKER_PATH" || fail "a Git operation is still in progress: $marker"
done

gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated"

ACTUAL_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
test "$ACTUAL_REPO" = "$EXPECTED_REPO" ||
  fail "expected $EXPECTED_REPO, found $ACTUAL_REPO"

git fetch origin main --tags
REMOTE_MAIN=$(git rev-parse origin/main)
MERGE_BASE=$(git merge-base HEAD origin/main)
test "$MERGE_BASE" = "$REMOTE_MAIN" ||
  fail "local main is behind or diverged from origin/main; update it safely first"

rg -q 'workflow_dispatch:' .github/workflows/release.yml ||
  fail "release workflow cannot be dispatched manually"
rg -q 'SPARKLE_PRIVATE_KEY' .github/workflows/release.yml ||
  fail "release workflow does not reference the Sparkle signing secret"
gh secret list --repo "$EXPECTED_REPO" --json name --jq '.[].name' |
  rg -qx 'SPARKLE_PRIVATE_KEY' ||
  fail "GitHub Actions secret SPARKLE_PRIVATE_KEY is missing"

git diff --check
git diff --cached --check
plutil -lint Resources/Info.plist >/dev/null

for script in scripts/*.sh .agents/skills/release-other-mac/scripts/*.sh
do
  test -f "$script" || continue
  sh -n "$script"
done

ruby -e '
  require "yaml"
  YAML.safe_load(File.read(".github/workflows/release.yml"), aliases: true)
'

swift test --disable-keychain -j 1

echo "preflight: release checks passed"
