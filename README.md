# Other Mac

<img src="Brand/other-mac-logo.png" alt="Other Mac icon" width="128">

I use two Macs with one monitor. Other Mac lets me switch the monitor input
with a keyboard shortcut, so I do not have to reach for the buttons underneath
it.

[Download the latest DMG](https://github.com/MarceloPrado/other-mac/releases/latest/download/Other-Mac.dmg)

Other Mac is free, open source, and built as a small native macOS menu bar app.
There is no account, analytics, or background service.

## Install

1. Download `Other-Mac.dmg` from the latest GitHub release.
2. Open it and drag **Other Mac** to Applications.
3. Open Other Mac, choose the monitor input used by your second computer, and
   record a shortcut.

The release is signed with a Developer ID certificate and notarized by Apple.

## Requirements

- An Apple silicon Mac running macOS 13 or newer
- An external display with DDC/CI enabled
- A second computer connected to another input on that display

`m1ddc`, the display-control tool bundled with Other Mac, does not support Intel
Macs.

## What it does

Other Mac asks `m1ddc` for the connected displays, remembers the selected
display by UUID, and sends the DDC/CI command for the input you chose. The
monitor does the actual switching.

The display detection follows the format tested with a Dell U3223QE:

1. Run `m1ddc display list`.
2. Parse lines in the form `[index] display name (UUID)`.
3. Save the selected monitor by UUID.
4. Find its current index each time the display list changes.
5. Switch with `m1ddc display <index> set input <value>`.

Common input values:

| Input | Value |
| --- | ---: |
| DisplayPort 1 | 15 |
| DisplayPort 2 | 16 |
| HDMI 1 | 17 |
| HDMI 2 | 18 |
| USB-C | 27 |

If your monitor has a USB/KVM hub, configure it to follow the active input so
your keyboard and mouse switch with the picture.

## Build from source

```sh
swift test
sh scripts/build-app.sh
open "dist/Other Mac.app"
```

This creates an ad hoc signed local build. To create a DMG:

```sh
sh scripts/package-dmg.sh
open dist/Other-Mac.dmg
```

## Publishing a release

The `Release` GitHub Action handles the public build. Run it from the Actions
tab with a version such as `0.1.0`, or push a tag such as `v0.1.0`.

Before the first release, add these repository secrets:

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded Developer ID Application `.p12` |
| `P12_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_ID` | Apple Developer account email |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_APP_PASSWORD` | App-specific password for notarization |

The workflow runs the tests, imports the certificate into a temporary
keychain, signs the app with the hardened runtime and a secure timestamp,
creates `Other-Mac.dmg`, submits it to Apple for notarization, staples the
ticket, and uploads the DMG to GitHub Releases.

For local notarization, install the Developer ID certificate in Keychain and
run:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  APP_VERSION=0.1.0 \
  sh scripts/package-dmg.sh

APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
  sh scripts/notarize.sh dist/Other-Mac.dmg
```

You can also store notarization credentials in Keychain and pass their profile
name as `NOTARY_KEYCHAIN_PROFILE`.

## Project structure

- AppKit owns the menu bar item, popover, and app activation.
- SwiftUI renders the popover and settings window.
- `KeyboardShortcuts` records the global shortcut.
- The bundled `m1ddc` executable handles DDC/CI.

The app imports settings from the old Electron version on first launch, so an
existing display and shortcut configuration carries over.

## License

Other Mac is available under the [MIT License](LICENSE). The bundled `m1ddc`
binary has its own MIT license in
`Sources/OtherMac/Resources/m1ddc-LICENSE.txt`.
