import KeyboardShortcuts
import SwiftUI

struct PopoverView: View {
  @ObservedObject var model: AppModel
  let openOnboarding: () -> Void
  let openSettings: () -> Void
  let hideMenuBarIcon: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      brand
      headline
      route
      swapButton
      shortcut
      footer
    }
    .padding(20)
    .frame(width: 338)
    .background(OtherMacStyle.parchment)
    .foregroundStyle(OtherMacStyle.ink)
  }

  private var brand: some View {
    HStack {
      Text("Other Mac")
        .font(.system(size: 13, weight: .semibold, design: .rounded))
      Spacer()
      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)
        .accessibilityLabel(statusLabel)
    }
    .padding(.bottom, 24)
  }

  private var headline: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(headlineText)
        .modifier(EditorialTitle())
      Text(model.statusMessage)
        .font(.system(size: 12))
        .foregroundStyle(OtherMacStyle.ink.opacity(0.62))
        .lineLimit(2)
    }
    .padding(.bottom, 22)
  }

  private var route: some View {
    HStack(spacing: 8) {
      Text("This Mac")
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(OtherMacStyle.ink.opacity(0.25))
      Image(systemName: "arrow.right")
      Text("Other Mac")
    }
    .font(.system(size: 11, weight: .medium))
    .padding(.bottom, 13)
    .accessibilityElement(children: .combine)
  }

  private var swapButton: some View {
    Button {
      Task {
        await model.swap()
      }
    } label: {
      HStack(spacing: 9) {
        Image(systemName: buttonIcon)
          .font(.system(size: 16, weight: .semibold))
        Text(buttonLabel)
          .font(.system(size: 22, weight: .semibold, design: .serif))
      }
      .frame(maxWidth: .infinity)
      .frame(height: 68)
      .foregroundStyle(Color.white)
      .background(OtherMacStyle.coral)
      .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
      .shadow(color: OtherMacStyle.coralShadow, radius: 0, y: 5)
    }
    .buttonStyle(.plain)
    .disabled(!model.isConfigured || model.swapState == .working)
    .opacity(model.isConfigured ? 1 : 0.48)
    .accessibilityHint("Switches every enabled display to its configured input.")
  }

  @ViewBuilder
  private var shortcut: some View {
    HStack {
      Spacer()
      if let shortcut = KeyboardShortcuts.getShortcut(for: .swapToOtherMac) {
        Text("or press \(shortcut.description)")
      } else {
        Button("Add a keyboard shortcut") {
          openSettings()
        }
        .buttonStyle(.plain)
        .underline()
      }
      Spacer()
    }
    .font(.system(size: 10, weight: .medium, design: .monospaced))
    .foregroundStyle(OtherMacStyle.ink.opacity(0.58))
    .padding(.top, 13)
    .padding(.bottom, 17)
  }

  private var footer: some View {
    HStack(spacing: 12) {
      Button("Setup…", systemImage: "sparkles") {
        openOnboarding()
      }
      Button("Settings…", systemImage: "gearshape") {
        openSettings()
      }
      Button("Hide Icon", systemImage: "eye.slash") {
        hideMenuBarIcon()
      }
      Spacer()
      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        Image(systemName: "power")
      }
      .accessibilityLabel("Quit Other Mac")
    }
    .buttonStyle(.plain)
    .font(.system(size: 11, weight: .medium))
    .foregroundStyle(OtherMacStyle.ink.opacity(0.65))
  }

  private var headlineText: String {
    switch model.swapState {
    case .idle:
      model.isConfigured ? "Ready when you are." : "Let’s find the other side."
    case .working:
      "Hopping over…"
    case .success:
      "Made it."
    case .failure:
      "Not quite."
    }
  }

  private var buttonLabel: String {
    switch model.swapState {
    case .working: "Swapping…"
    case .success: "Swapped"
    default: "Swap"
    }
  }

  private var buttonIcon: String {
    switch model.swapState {
    case .working: "ellipsis"
    case .success: "checkmark"
    default: "arrow.triangle.2.circlepath"
    }
  }

  private var statusColor: Color {
    switch model.swapState {
    case .failure: .red
    case .working: .orange
    default: model.isConfigured ? .green : .secondary
    }
  }

  private var statusLabel: String {
    switch model.swapState {
    case .failure: "Needs attention"
    case .working: "Switching"
    default: model.isConfigured ? "Ready" : "Not configured"
    }
  }
}
