import AppKit
import KeyboardShortcuts
import Testing

@testable import OtherMac

struct LegacyShortcutParserTests {
  @Test
  func parsesTheShortcutUsedByTheTestedElectronConfiguration() {
    let shortcut = LegacyShortcutParser.parse("Command+Control+Alt+Left")

    #expect(shortcut?.key == .leftArrow)
    #expect(shortcut?.modifiers == [.command, .control, .option])
  }

  @Test
  func parsesTheOriginalDefaultShortcut() {
    let shortcut = LegacyShortcutParser.parse("Alt+Space")

    #expect(shortcut?.key == .space)
    #expect(shortcut?.modifiers == [.option])
  }
}
