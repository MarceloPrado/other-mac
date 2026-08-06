# Other Mac

Other Mac is a tiny native macOS menu-bar app that moves an external display
from this Mac to the other one. Use one warm, obvious **Swap** button or record
a global keyboard shortcut and never leave the keyboard.

The app is intentionally native:

- AppKit owns the status item, popover, activation, and recovery behavior.
- SwiftUI renders the playful popover and compact settings window.
- `KeyboardShortcuts` records a global hotkey without an Accessibility prompt.
- The proven `m1ddc` command used by the original Electron prototype remains
  the DDC backend.

## Requirements

- Apple Silicon Mac
- macOS 13 or later
- A DDC/CI-capable external display
- DDC/CI enabled in the monitor's settings

`m1ddc` does not support Intel Macs. The app currently targets direct,
notarized distribution rather than the Mac App Store.

## Build and run

```sh
swift test
sh scripts/build-app.sh
open "dist/Other Mac.app"
```

Or use mise:

```sh
mise try
```

The build script creates an ad-hoc signed app at `dist/Other Mac.app`.

## How display detection works

The backend intentionally preserves the contract that was tested on a Dell
U3223QE:

1. Run `m1ddc display list`.
2. Parse lines in the format `[index] display name (UUID)`.
3. Store configuration against the stable UUID.
4. Resolve the display's current index on every refresh.
5. Switch with `m1ddc display <index> set input <value>`.

On first native launch, settings are imported from the Electron application
support directory. If no all-display shortcut exists, a shortcut attached to
the single enabled display becomes the new global Swap shortcut.

Known standard input values:

| Input | Value |
| --- | ---: |
| DisplayPort 1 | 15 |
| DisplayPort 2 | 16 |
| HDMI 1 | 17 |
| HDMI 2 | 18 |
| USB-C | 27 |

The packaged app uses its bundled `m1ddc` binary. Development builds also fall
back to `/opt/homebrew/bin/m1ddc` and `/usr/local/bin/m1ddc`.

## Moving the keyboard and mouse

Other Mac changes the monitor input. For peripherals to follow automatically,
configure the monitor's USB/KVM to follow its active input, or use a keyboard
and mouse connected to both Macs.

## Brand assets

- `Brand/other-mac-logo.png` — generated master app icon artwork
- `Brand/other-mac-menubar.svg` — deterministic monochrome menu-bar companion
- `Sources/OtherMac/Resources/AppIcon.icns` — packaged macOS icon

The bundled `m1ddc` binary is distributed under the MIT license included in the
app resources.
