import AppKit
import Foundation
import KeyboardShortcuts

enum LegacyShortcutParser {
  static func parse(_ accelerator: String) -> KeyboardShortcuts.Shortcut? {
    let parts =
      accelerator
      .split(separator: "+")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty }

    var modifiers: NSEvent.ModifierFlags = []
    var key: KeyboardShortcuts.Key?

    for part in parts {
      switch part {
      case "command", "commandorcontrol", "cmd":
        modifiers.insert(.command)
      case "control", "ctrl":
        modifiers.insert(.control)
      case "alt", "option":
        modifiers.insert(.option)
      case "shift":
        modifiers.insert(.shift)
      default:
        key = keyValue(part)
      }
    }

    guard let key, !modifiers.isEmpty else { return nil }
    return KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
  }

  private static func keyValue(_ value: String) -> KeyboardShortcuts.Key? {
    let namedKeys: [String: KeyboardShortcuts.Key] = [
      "space": .space,
      "left": .leftArrow,
      "right": .rightArrow,
      "up": .upArrow,
      "down": .downArrow,
      "return": .return,
      "enter": .return,
      "tab": .tab,
      "escape": .escape,
      "backspace": .delete,
      "delete": .deleteForward,
      "home": .home,
      "end": .end,
      "pageup": .pageUp,
      "pagedown": .pageDown,
    ]
    if let key = namedKeys[value] {
      return key
    }

    let letters: [String: KeyboardShortcuts.Key] = [
      "a": .a, "b": .b, "c": .c, "d": .d, "e": .e, "f": .f,
      "g": .g, "h": .h, "i": .i, "j": .j, "k": .k, "l": .l,
      "m": .m, "n": .n, "o": .o, "p": .p, "q": .q, "r": .r,
      "s": .s, "t": .t, "u": .u, "v": .v, "w": .w, "x": .x,
      "y": .y, "z": .z,
    ]
    if let key = letters[value] {
      return key
    }

    let numbers: [String: KeyboardShortcuts.Key] = [
      "0": .zero, "1": .one, "2": .two, "3": .three, "4": .four,
      "5": .five, "6": .six, "7": .seven, "8": .eight, "9": .nine,
    ]
    return numbers[value]
  }
}

@MainActor
enum LegacyShortcutMigrator {
  static func migrateIfNeeded(applicationSupportURL: URL) {
    guard KeyboardShortcuts.getShortcut(for: .swapToOtherMac) == nil else {
      return
    }

    let candidates = ["zap-source-switcher", "Zap"].map {
      applicationSupportURL
        .appendingPathComponent($0, isDirectory: true)
        .appendingPathComponent("settings.json")
    }

    for url in candidates {
      guard
        let data = try? Data(contentsOf: url),
        let object = try? JSONSerialization.jsonObject(with: data)
          as? [String: Any],
        let accelerator = preferredAccelerator(in: object),
        let shortcut = LegacyShortcutParser.parse(accelerator)
      else {
        continue
      }

      KeyboardShortcuts.setShortcut(shortcut, for: .swapToOtherMac)
      return
    }
  }

  private static func preferredAccelerator(in object: [String: Any]) -> String? {
    if let shortcut = object["swapAllShortcut"] as? String,
      !shortcut.isEmpty
    {
      return shortcut
    }

    guard let configs = object["displayConfigs"] as? [String: [String: Any]] else {
      return nil
    }

    return configs.values.lazy.compactMap { config in
      guard config["enabled"] as? Bool != false else { return nil }
      guard let shortcut = config["shortcut"] as? String, !shortcut.isEmpty else {
        return nil
      }
      return shortcut
    }.first
  }
}
