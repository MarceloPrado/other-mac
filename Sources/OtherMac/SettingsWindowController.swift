import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
  init(
    model: AppModel,
    openOnboarding: @escaping () -> Void,
    checkForUpdates: @escaping () -> Void
  ) {
    let content = SettingsView(
      model: model,
      openOnboarding: openOnboarding,
      checkForUpdates: checkForUpdates
    )
    let hostingController = NSHostingController(rootView: content)
    let window = NSWindow(contentViewController: hostingController)

    window.title = "Other Mac Settings"
    window.setContentSize(NSSize(width: 560, height: 610))
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.isReleasedWhenClosed = false
    window.center()

    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func present() {
    NSApplication.shared.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.center()
    window?.makeKeyAndOrderFront(nil)
  }
}
