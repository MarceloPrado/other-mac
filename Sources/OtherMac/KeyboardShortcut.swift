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
}
