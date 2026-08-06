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
      statusBar.show()
    }

    LegacyShortcutMigrator.migrateIfNeeded(
      applicationSupportURL: model.applicationSupportURL
    )
    KeyboardShortcuts.onKeyUp(for: .swapToOtherMac) { [weak model] in
      Task { @MainActor in
        await model?.swap()
      }
    }

    model.start()
    model.reconcileLaunchAtLogin()

    if !model.settings.completedOnboarding {
      DispatchQueue.main.async {
        statusBar.showOnboarding()
      }
    }

    if let resultPath = ProcessInfo.processInfo.environment[
      "OTHER_MAC_LIFECYCLE_SMOKE_RESULT"
    ], !resultPath.isEmpty {
      let iterations =
        ProcessInfo.processInfo.environment["OTHER_MAC_LIFECYCLE_SMOKE_ITERATIONS"]
        .flatMap(Int.init) ?? 20
      Task {
        let result = await statusBar.runLifecycleSmoke(iterations: iterations)
        try? result.write(
          to: URL(fileURLWithPath: resultPath),
          atomically: true,
          encoding: .utf8
        )
      }
    }
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

  func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    false
  }
}
