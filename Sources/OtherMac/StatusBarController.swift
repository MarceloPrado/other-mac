import AppKit
import Combine
import KeyboardShortcuts
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
  private let model: AppModel
  private let checkForUpdates: @MainActor () -> Void
  private var settingsWindow: SettingsWindowController?
  private var onboardingWindow: OnboardingWindowController?
  private let popover = NSPopover()
  private var statusItem: NSStatusItem?
  private var cancellables: Set<AnyCancellable> = []

  init(
    model: AppModel,
    checkForUpdates: @escaping @MainActor () -> Void
  ) {
    self.model = model
    self.checkForUpdates = checkForUpdates
    super.init()

    popover.behavior = .transient
    popover.animates = true
    let contentViewController = NSHostingController(
      rootView: PopoverView(
        model: model,
        openOnboarding: { [weak self] in
          self?.closePopover { [weak self] in
            self?.showOnboarding()
          }
        },
        openSettings: { [weak self] in
          self?.closePopover { [weak self] in
            self?.openSettings()
          }
        },
        hideMenuBarIcon: { [weak self] in
          self?.model.setShowMenuBarIcon(false)
        }
      )
    )
    contentViewController.sizingOptions = [.preferredContentSize]
    popover.contentViewController = contentViewController

    model.$settings
      .map(\.showMenuBarIcon)
      .removeDuplicates()
      .sink { [weak self] isVisible in
        if isVisible {
          self?.show()
        } else {
          self?.hide()
        }
      }
      .store(in: &cancellables)
  }

  func show() {
    if statusItem == nil {
      let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
      item.autosaveName = "OtherMacStatusItem"

      if let button = item.button {
        button.image = MenuBarIcon.make()
        button.imagePosition = .imageOnly
        button.toolTip = "Other Mac"
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
      }
      statusItem = item
    }

    statusItem?.isVisible = true
  }

  func hide() {
    popover.close()
    if let statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
      self.statusItem = nil
    }
  }

  func restoreAndOpen() {
    model.setShowMenuBarIcon(true)
    show()
    if !model.needsOnboarding {
      openPopover()
    } else {
      showOnboarding()
    }
  }

  func showOnboarding() {
    if onboardingWindow == nil {
      onboardingWindow = OnboardingWindowController(model: model) { [weak self] in
        self?.openPopover()
      }
    }
    onboardingWindow?.present()
  }

  @objc private func togglePopover() {
    if popover.isShown {
      popover.close()
    } else {
      openPopover()
    }
  }

  private func openPopover() {
    guard let button = statusItem?.button else { return }
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
  }

  private func openSettings() {
    if settingsWindow == nil {
      settingsWindow = SettingsWindowController(
        model: model,
        openOnboarding: { [weak self] in
          self?.showOnboarding()
        },
        checkForUpdates: { [weak self] in
          self?.checkForUpdates()
        }
      )
    }
    settingsWindow?.present()
  }

  private func closePopover(
    then action: @escaping @MainActor @Sendable () -> Void
  ) {
    popover.close()
    DispatchQueue.main.async(execute: action)
  }

  func runLifecycleSmoke(iterations: Int) async -> String {
    let iterations = max(1, iterations)
    let popoverWasAnimated = popover.animates
    popover.animates = false
    defer {
      popover.animates = popoverWasAnimated
    }
    await settle()

    show()
    guard statusItem?.isVisible == true, statusItem?.button != nil else {
      return "FAIL: status item was not visible after show"
    }
    if CommandLine.arguments.contains("-KeyboardShortcuts_swapToOtherMac") {
      guard KeyboardShortcuts.getShortcut(for: .swapToOtherMac)?.key == .space else {
        return "FAIL: legacy Alt+Space shortcut was not loaded"
      }
    }

    for iteration in 1...iterations {
      openPopover()
      await settle()
      guard popover.isShown else {
        return "FAIL: popover did not open at iteration \(iteration)"
      }

      popover.close()
      await settle()
      guard !popover.isShown else {
        return "FAIL: popover did not close at iteration \(iteration)"
      }

      openSettings()
      await settle()
      guard settingsWindow?.window?.isVisible == true else {
        return "FAIL: Settings did not open at iteration \(iteration)"
      }

      settingsWindow?.close()
      await settle()
      guard statusItem?.isVisible == true else {
        return "FAIL: status item vanished after Settings iteration \(iteration)"
      }
    }

    model.setShowMenuBarIcon(false)
    await settle()
    guard statusItem == nil else {
      return "FAIL: status item remained after hide"
    }

    restoreAndOpen()
    await settle()
    guard statusItem?.isVisible == true else {
      return "FAIL: status item did not return after app reopen"
    }
    popover.close()
    onboardingWindow?.close()
    await settle()

    showOnboarding()
    await settle()
    guard onboardingWindow?.window?.isVisible == true else {
      return "FAIL: onboarding did not open"
    }
    onboardingWindow?.close()
    await settle()

    showOnboarding()
    await settle()
    guard onboardingWindow?.window?.isVisible == true else {
      return "FAIL: onboarding did not reopen"
    }
    onboardingWindow?.close()

    return "PASS: \(iterations) popover/Settings cycles, icon hide/show, onboarding reopen"
  }

  private func settle() async {
    try? await Task.sleep(for: .milliseconds(300))
  }
}
