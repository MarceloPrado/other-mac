import AppKit
import KeyboardShortcuts
import SwiftUI

struct ShortcutRecorder: View {
  private let label: String
  private let name: KeyboardShortcuts.Name
  private let onChange: (KeyboardShortcuts.Shortcut?) -> Void

  @State private var shortcut: KeyboardShortcuts.Shortcut?

  init(
    _ label: String,
    name: KeyboardShortcuts.Name,
    onChange: @escaping (KeyboardShortcuts.Shortcut?) -> Void = { _ in }
  ) {
    self.label = label
    self.name = name
    self.onChange = onChange
    _shortcut = State(initialValue: KeyboardShortcuts.getShortcut(for: name))
  }

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      NativeShortcutRecorder(name: name) { newShortcut in
        shortcut = newShortcut
        onChange(newShortcut)
      }
      .frame(width: 156, height: 26)

      Button {
        updateShortcut(nil)
      } label: {
        Image(systemName: "xmark.circle.fill")
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .accessibilityLabel("Clear shortcut")
      .disabled(shortcut == nil)
    }
  }

  private func updateShortcut(_ newShortcut: KeyboardShortcuts.Shortcut?) {
    KeyboardShortcuts.setShortcut(newShortcut, for: name)
    shortcut = newShortcut
    onChange(newShortcut)
  }
}

private struct NativeShortcutRecorder: NSViewRepresentable {
  let name: KeyboardShortcuts.Name
  let onChange: (KeyboardShortcuts.Shortcut?) -> Void

  func makeNSView(context: Context) -> ShortcutRecorderButton {
    ShortcutRecorderButton(name: name, onChange: onChange)
  }

  func updateNSView(_ view: ShortcutRecorderButton, context: Context) {
    view.refresh()
  }
}

@MainActor
private final class ShortcutRecorderButton: NSButton {
  private let shortcutName: KeyboardShortcuts.Name
  private let onChange: (KeyboardShortcuts.Shortcut?) -> Void
  private var isRecording = false

  init(
    name: KeyboardShortcuts.Name,
    onChange: @escaping (KeyboardShortcuts.Shortcut?) -> Void
  ) {
    shortcutName = name
    self.onChange = onChange
    super.init(frame: .zero)

    bezelStyle = .rounded
    setButtonType(.momentaryPushIn)
    target = self
    action = #selector(beginRecording)
    focusRingType = .default
    setAccessibilityLabel("Record keyboard shortcut")
    refresh()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override func keyDown(with event: NSEvent) {
    if isRecording {
      capture(event)
    } else {
      super.keyDown(with: event)
    }
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard isRecording else {
      return super.performKeyEquivalent(with: event)
    }
    capture(event)
    return true
  }

  func refresh() {
    guard !isRecording else { return }
    title =
      KeyboardShortcuts.getShortcut(for: shortcutName)
      .map(ShortcutDisplayName.make)
      ?? "Record Shortcut"
  }

  @objc private func beginRecording() {
    isRecording = true
    title = "Press shortcut…"
    window?.makeFirstResponder(self)
  }

  private func capture(_ event: NSEvent) {
    switch event.keyCode {
    case 53:
      finishRecording()
      return
    case 51, 117:
      save(nil)
      return
    default:
      break
    }

    let allowedModifiers: NSEvent.ModifierFlags = [
      .command, .control, .option, .shift, .function,
    ]
    let modifiers = event.modifierFlags.intersection(allowedModifiers)
    guard !modifiers.isEmpty,
      let shortcut = KeyboardShortcuts.Shortcut(event: event),
      shortcut.key != nil,
      !shortcut.isTakenBySystem
    else {
      NSSound.beep()
      return
    }

    save(shortcut)
  }

  private func save(_ shortcut: KeyboardShortcuts.Shortcut?) {
    KeyboardShortcuts.setShortcut(shortcut, for: shortcutName)
    onChange(shortcut)
    finishRecording()
  }

  private func finishRecording() {
    isRecording = false
    refresh()
    window?.makeFirstResponder(nil)
  }
}
