import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
  private let model: AppModel
  private var settingsWindow: SettingsWindowController?
  private let popover = NSPopover()
  private var statusItem: NSStatusItem?
  private var cancellables: Set<AnyCancellable> = []

  init(model: AppModel) {
    self.model = model
    super.init()

    popover.behavior = .transient
    popover.animates = true
    popover.contentSize = NSSize(width: 338, height: 370)
    popover.contentViewController = NSHostingController(
      rootView: PopoverView(
        model: model,
        openSettings: { [weak self] in
          self?.popover.close()
          self?.openSettings()
        },
        hideMenuBarIcon: { [weak self] in
          self?.model.setShowMenuBarIcon(false)
        }
      )
    )

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

  func show(openPopover: Bool = false) {
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

    if openPopover {
      DispatchQueue.main.async { [weak self] in
        self?.openPopover()
      }
    }
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
    show(openPopover: true)
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
      settingsWindow = SettingsWindowController(model: model)
    }
    settingsWindow?.present()
  }
}
