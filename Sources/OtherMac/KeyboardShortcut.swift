import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let swapToOtherMac = Self("swapToOtherMac")
}

@MainActor
enum ShortcutDisplayName {
  static func make(_ shortcut: KeyboardShortcuts.Shortcut) -> String {
    guard shortcut.key == .space else {
      return shortcut.description
    }

    let modifiers = shortcut.modifiers
    var result = ""
    if modifiers.contains(.control) {
      result += "⌃"
    }
    if modifiers.contains(.option) {
      result += "⌥"
    }
    if modifiers.contains(.shift) {
      result += "⇧"
    }
    if modifiers.contains(.command) {
      result += "⌘"
    }
    return result + "Space"
  }

  static func keycaps(_ shortcut: KeyboardShortcuts.Shortcut) -> [String] {
    let modifiers = shortcut.modifiers
    var result: [String] = []

    if modifiers.contains(.control) {
      result.append("⌃")
    }
    if modifiers.contains(.option) {
      result.append("⌥")
    }
    if modifiers.contains(.shift) {
      result.append("⇧")
    }
    if modifiers.contains(.command) {
      result.append("⌘")
    }

    var key = make(shortcut)
    for modifier in ["⌃", "⌥", "⇧", "⌘"] {
      key = key.replacingOccurrences(of: modifier, with: "")
    }
    if !key.isEmpty {
      result.append(key)
    }

    return result
  }
}
