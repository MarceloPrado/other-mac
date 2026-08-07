import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let swapToOtherMac = Self("swapToOtherMac")
}

@MainActor
enum ShortcutDisplayName {
  static func make(_ shortcut: KeyboardShortcuts.Shortcut) -> String {
    modifierKeycaps(shortcut.modifiers).joined()
      + keyName(shortcut.key)
  }

  static func keycaps(_ shortcut: KeyboardShortcuts.Shortcut) -> [String] {
    var result = modifierKeycaps(shortcut.modifiers)
    let key = keyName(shortcut.key)
    if !key.isEmpty {
      result.append(key)
    }
    return result
  }

  private static func modifierKeycaps(
    _ modifiers: NSEvent.ModifierFlags
  ) -> [String] {
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
    return result
  }

  private static func keyName(
    _ key: KeyboardShortcuts.Key?
  ) -> String {
    guard let key else { return "" }

    let names: [KeyboardShortcuts.Key: String] = [
      .a: "A", .b: "B", .c: "C", .d: "D", .e: "E", .f: "F",
      .g: "G", .h: "H", .i: "I", .j: "J", .k: "K", .l: "L",
      .m: "M", .n: "N", .o: "O", .p: "P", .q: "Q", .r: "R",
      .s: "S", .t: "T", .u: "U", .v: "V", .w: "W", .x: "X",
      .y: "Y", .z: "Z",
      .zero: "0", .one: "1", .two: "2", .three: "3", .four: "4",
      .five: "5", .six: "6", .seven: "7", .eight: "8", .nine: "9",
      .return: "↩", .space: "Space", .tab: "⇥", .escape: "Esc",
      .delete: "⌫", .deleteForward: "⌦",
      .leftArrow: "←", .rightArrow: "→", .upArrow: "↑", .downArrow: "↓",
      .home: "Home", .end: "End", .pageUp: "Page Up", .pageDown: "Page Down",
      .help: "Help", .mute: "Mute", .volumeUp: "Volume Up",
      .volumeDown: "Volume Down",
      .backslash: "\\", .backtick: "`", .comma: ",", .equal: "=",
      .minus: "-", .period: ".", .quote: "'", .semicolon: ";",
      .slash: "/", .leftBracket: "[", .rightBracket: "]",
      .f1: "F1", .f2: "F2", .f3: "F3", .f4: "F4", .f5: "F5",
      .f6: "F6", .f7: "F7", .f8: "F8", .f9: "F9", .f10: "F10",
      .f11: "F11", .f12: "F12", .f13: "F13", .f14: "F14",
      .f15: "F15", .f16: "F16", .f17: "F17", .f18: "F18",
      .f19: "F19", .f20: "F20",
      .keypad0: "Num 0", .keypad1: "Num 1", .keypad2: "Num 2",
      .keypad3: "Num 3", .keypad4: "Num 4", .keypad5: "Num 5",
      .keypad6: "Num 6", .keypad7: "Num 7", .keypad8: "Num 8",
      .keypad9: "Num 9", .keypadClear: "Num Clear",
      .keypadDecimal: "Num .", .keypadDivide: "Num /",
      .keypadEnter: "Num ↩", .keypadEquals: "Num =",
      .keypadMinus: "Num -", .keypadMultiply: "Num ×",
      .keypadPlus: "Num +",
    ]
    return names[key] ?? "Key \(key.rawValue)"
  }
}
