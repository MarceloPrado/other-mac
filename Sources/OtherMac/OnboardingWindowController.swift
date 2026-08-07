import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
  private let model: AppModel
  private let hostingController: NSHostingController<AnyView>
  private let onFinish: () -> Void

  init(model: AppModel, onFinish: @escaping () -> Void) {
    self.model = model
    self.onFinish = onFinish
    hostingController = NSHostingController(
      rootView: AnyView(EmptyView())
    )

    let window = NSWindow(contentViewController: hostingController)
    window.title = "Set Up Other Mac"
    window.setContentSize(NSSize(width: 620, height: 560))
    window.styleMask = [.titled, .closable]
    window.isReleasedWhenClosed = false
    window.center()

    super.init(window: window)
    window.delegate = self
    hostingController.rootView = makeRootView()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func present() {
    model.beginOnboarding()
    hostingController.rootView = makeRootView()
    showWindow(nil)
    window?.center()
    window?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  private func makeRootView() -> AnyView {
    AnyView(
      OnboardingView(model: model) { [weak self] in
        self?.complete()
      }
      .id(UUID())
    )
  }

  private func complete() {
    model.completeOnboarding()
    close()
    onFinish()
  }

  func windowWillClose(_ notification: Notification) {
    model.endOnboarding()
  }
}
