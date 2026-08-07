import AppKit
import KeyboardShortcuts
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = AppModel()
  private var statusBarController: StatusBarController?
  private var updaterController: SPUStandardUpdaterController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let environment = ProcessInfo.processInfo.environment
    let isLifecycleSmoke =
      environment["OTHER_MAC_LIFECYCLE_SMOKE_RESULT"]?.isEmpty == false

    if SingleInstanceController.activateExistingInstance(
      isLifecycleSmoke: isLifecycleSmoke
    ) {
      NSApplication.shared.terminate(nil)
      return
    }

    NSApplication.shared.setActivationPolicy(.accessory)

    let updater = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
    updaterController = updater

    let statusBar = StatusBarController(
      model: model,
      checkForUpdates: { [weak updater] in
        updater?.checkForUpdates(nil)
      }
    )
    statusBarController = statusBar

    if model.settings.showMenuBarIcon {
      statusBar.show()
    }

    LegacyShortcutMigrator.migrateIfNeeded(
      applicationSupportURL: model.applicationSupportURL
    )
    if !isLifecycleSmoke {
      KeyboardShortcuts.onKeyDown(for: .swapToOtherMac) { [weak model] in
        Task { @MainActor in
          model?.handleShortcutKeyDown()
        }
      }
      KeyboardShortcuts.onKeyUp(for: .swapToOtherMac) { [weak model] in
        Task { @MainActor in
          await model?.handleShortcutKeyUp()
        }
      }
    }

    model.start()
    model.reconcileLaunchAtLogin()

    if model.needsOnboarding {
      DispatchQueue.main.async {
        statusBar.showOnboarding()
      }
    }

    if let resultPath = environment["OTHER_MAC_LIFECYCLE_SMOKE_RESULT"],
      !resultPath.isEmpty
    {
      let iterations =
        environment["OTHER_MAC_LIFECYCLE_SMOKE_ITERATIONS"]
        .flatMap(Int.init) ?? 20
      Task {
        let result = await statusBar.runLifecycleSmoke(iterations: iterations)
        try? result.write(
          to: URL(fileURLWithPath: resultPath),
          atomically: true,
          encoding: .utf8
        )
        try? await Task.sleep(for: .seconds(3))
        NSApplication.shared.terminate(nil)
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
