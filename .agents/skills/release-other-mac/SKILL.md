---
name: release-other-mac
description: Release and verify a production version of the Other Mac macOS app through its GitHub Actions and Sparkle update pipeline. Use when the user says "launch a new version", "ship a release", "publish a new version", "cut a release", "release Other Mac", or asks to complete or diagnose the app's release process.
---

# Release Other Mac

Carry a release from the repository's current state to a verified public GitHub
Release and Sparkle feed. Work autonomously through normal release decisions,
but stop when proceeding would risk publishing the wrong code or version.

## Authorization Contract

Treat a direct imperative such as "launch a new version" as authorization to:

- review and commit release-ready changes already in this repository;
- push a fast-forward update to `origin/main`;
- dispatch the repository's `Release` workflow;
- wait for the workflow, inspect failures, and perform read-only release checks.

That instruction does not authorize force-pushing, discarding local changes,
deleting or overwriting tags/releases, rotating the Sparkle key, weakening
checks, or publishing changes whose purpose is unclear. Ask the user only when
one of those boundaries or another material ambiguity is reached.

## Release Invariants

- Release only from `main`, based on the current `origin/main`.
- Never discard, stash, or rewrite user changes.
- Inspect every uncommitted change before staging it. Include it only when it is
  coherent, complete, and part of the intended release.
- Do not release with unresolved conflicts, an in-progress Git operation,
  failing tests, or ambiguous product changes.
- Use the `Release` workflow via `workflow_dispatch`; a normal push to `main`
  does not publish a version.
- Never reuse an existing tag or GitHub Release version.
- Keep the Sparkle private key in GitHub Actions secrets. Never print, export,
  or retrieve its value during a release.
- Do not edit version strings in source. The workflow injects `APP_VERSION` and
  `BUILD_NUMBER` into the packaged app.
- Finish only after the GitHub Release, updater archive, DMG, and public
  `appcast.xml` have been verified.

## 1. Establish the Release State

Run from the repository root:

```sh
git status --short --branch
git fetch origin main --tags
git log --oneline --decorate --graph -20
git diff
git diff --cached
```

Inspect any untracked files explicitly. Also check for an in-progress rebase,
merge, cherry-pick, or revert. If the working tree is clean and local `main` is
strictly behind `origin/main`, update it with `git pull --ff-only` and inspect
again. Do not rebase or merge a dirty or divergent branch during a release.

Review the full change set, not just filenames. If unfinished or unrelated
changes make the release contents uncertain, explain the exact files and ask
the user what belongs in the release. Otherwise continue without asking.

## 2. Choose the Version

Honor an explicit version from the user after validating it. Otherwise inspect
the latest stable `vX.Y.Z` tag and all changes since it, then choose the smallest
correct SemVer increment:

- **patch** for fixes, performance, compatibility, polish, or release-only work;
- **minor** for a new user-visible capability or meaningfully expanded behavior;
- **major** only when the user explicitly intends a breaking release.

Use a stable `X.Y.Z` version. If the user requests a prerelease, stop and
explain that the current workflow always publishes a stable latest release, so
prerelease behavior must be implemented separately. Confirm that both checks
fail before selecting the version:

```sh
git rev-parse --verify --quiet "refs/tags/v$VERSION"
gh release view "v$VERSION" --repo MarceloPrado/other-mac
```

Also ensure the selected version is greater than the latest stable version.
Never silently pick a different version merely because the intended one exists.

## 3. Draft User-Facing Highlights

Write concise Markdown that explains outcomes, not implementation details.
Prefer one short opening sentence and one to four bullets. Mention important
setup or behavior changes. Do not repeat raw commit subjects: the workflow adds
the first-parent commit list and comparison link automatically.

Keep the final highlights in a temporary file so multiline Markdown can be
passed to GitHub CLI without shell-quoting mistakes:

```sh
RELEASE_NOTES_FILE=$(mktemp "${TMPDIR:-/tmp}/other-mac-notes.XXXXXX")
```

Remove that exact temporary file after dispatching the workflow.

## 4. Validate and Commit

Run the skill's deterministic preflight:

```sh
sh .agents/skills/release-other-mac/scripts/preflight.sh
```

If it fails, fix only issues that are clearly within the requested release,
then rerun it. Never bypass a failure.

If the working tree contains reviewed release changes, stage explicit paths,
inspect `git diff --cached`, and create one clear commit describing the product
change. Do not use `git add -A` until every changed and untracked path has been
reviewed and confirmed as release content.

Before pushing, record the exact commit and ensure no intended change remains
unstaged:

```sh
git status --short
git rev-parse HEAD
git log --oneline origin/main..HEAD
```

Push only a fast-forward update:

```sh
git push origin main
```

Record the resulting full commit SHA as `RELEASE_SHA`.

## 5. Dispatch and Monitor

Dispatch the workflow at the pushed `main` commit:

```sh
gh workflow run release.yml \
  --repo MarceloPrado/other-mac \
  --ref main \
  -f "version=$VERSION" \
  -F "highlights=@$RELEASE_NOTES_FILE"
```

Find the new `workflow_dispatch` run whose `headSha` equals `RELEASE_SHA`.
Do not assume the first listed run is yours. Then wait for it:

```sh
gh run watch "$RUN_ID" --repo MarceloPrado/other-mac --exit-status
```

If it fails, inspect `gh run view "$RUN_ID" --log-failed`. Determine whether a
tag or release was created before retrying. A retry with the same version is
allowed only when no public release exists, any draft targets `RELEASE_SHA`,
and the repair is clearly safe. Never overwrite an already-published release.

## 6. Verify Production

After the workflow succeeds, run:

```sh
sh .agents/skills/release-other-mac/scripts/verify-release.sh \
  "$VERSION" "$RELEASE_SHA"
```

This verifies the published/latest state, expected assets, release target,
public Sparkle feed, appcast metadata, archive integrity, app version,
framework embedding, code signatures, and DMG integrity.

Report the version, release URL, release commit, and a short summary of the
verified assets. If verification fails after publication, report the exact
failure prominently; do not delete or mutate the public release without a new
explicit instruction.

## Failure Handling

- Preserve all diagnostics and give the user the failed command and relevant
  output.
- Do not create a higher version to hide a failed workflow.
- Do not claim success from a green workflow alone; post-release verification
  is required.
- If GitHub is temporarily unavailable, continue bounded monitoring when
  possible. Otherwise report the external outage and the run/release URL.
