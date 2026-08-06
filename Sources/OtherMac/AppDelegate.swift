import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = AppModel()
  private var statusBarController: StatusBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)

    let statusBar = StatusBarController(model: model)
    statusBarController = statusBar

    if model.settings.showMenuBarIcon {
      statusBar.show(openPopover: !model.settings.completedOnboarding)
    }

    LegacyShortcutMigrator.migrateIfNeeded()
    KeyboardShortcuts.onKeyUp(for: .swapToOtherMac) { [weak model] in
      Task { @MainActor in
        await model?.swap()
      }
    }

    model.start()
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    statusBarController?.restoreAndOpen()
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    KeyboardShortcuts.disable(.swapToOtherMac)
  }
}
