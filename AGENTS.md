# Other Mac

Native macOS 13+ menu bar app written in Swift 6.1. AppKit owns the app
lifecycle and windows; SwiftUI renders the popover, onboarding, and settings.

## Code map

- `AppDelegate.swift` wires the app, global shortcut, Sparkle, and status item.
- `AppModel.swift` is the `@MainActor` source of application state and behavior.
- `DisplayBackend.swift` defines display I/O; `M1DDCBackend.swift` runs the
  bundled `m1ddc` helper. Keep this boundary injectable for tests.
- `SettingsStore.swift` persists versioned JSON under Application Support.
- `StatusBarController.swift` owns AppKit presentation; the `*View.swift` files
  contain SwiftUI.
- Tests live in `Tests/OtherMacTests`.

## Commands

```sh
swift test --disable-keychain -j 1
sh scripts/build-app.sh
sh scripts/verify-app.sh "dist/Other Mac.app"
```

Use two-space Swift indentation and add focused tests for behavior changes.
Preserve settings migrations and legacy shortcut compatibility. Do not replace
the bundled `m1ddc` binary unless explicitly requested.

For “launch a new version” or any production release, use the repo-local
`$release-other-mac` skill in `.agents/skills/release-other-mac/SKILL.md`.
Never discard unrelated changes in a dirty worktree.
