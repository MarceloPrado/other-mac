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
2. Try to open the DMG. macOS will block it because it is not notarized.
3. Open **System Settings → Privacy & Security**, scroll to Security, and click
   **Open Anyway** for `Other-Mac.dmg`.
4. The disk image will mount. Drag **Other Mac** to Applications.
5. Open the copied app from Applications or Spotlight. macOS will block it
   again.
6. Return to **System Settings → Privacy & Security** and click **Open Anyway**
   for the **Other Mac** app.
7. Open Other Mac, choose the monitor input used by your second computer, and
   record a shortcut.

Other Mac uses a free ad hoc signature. This verifies the app bundle is
internally consistent, but it does not identify me to Gatekeeper. Gatekeeper
asks you to approve the downloaded DMG and the copied app separately because
the release is not notarized. Apple explains the process in
[Open apps safely on your Mac](https://support.apple.com/en-gb/102445).

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
brew install create-dmg
sh scripts/package-dmg.sh
open dist/Other-Mac.dmg
```

Verify the packaged resources, signatures, clean-install lifecycle, and v0.1.0
preference upgrade with:

```sh
sh scripts/verify-app.sh "dist/Other Mac.app"
sh scripts/smoke-lifecycle.sh "dist/Other Mac.app" clean
sh scripts/smoke-lifecycle.sh "dist/Other Mac.app" legacy
```

## Publishing a release

The `Release` GitHub Action handles the public build without Apple credentials
or paid services. Run it from the Actions tab with a version such as `0.1.0`,
or push a tag such as `v0.1.0`.

The workflow runs the tests, builds an ad hoc signed app, creates the custom
drag-to-Applications DMG, and uploads `Other-Mac.dmg` to GitHub Releases.

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
