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
      HStack(spacing: 5) {
        Circle()
          .fill(statusColor)
          .frame(width: 7, height: 7)
        Text(statusLabel)
          .font(.system(size: 9, weight: .semibold, design: .rounded))
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(OtherMacStyle.ink.opacity(0.055))
      .clipShape(Capsule())
      .accessibilityElement(children: .combine)
    }
    .padding(.bottom, 20)
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
    .padding(.bottom, 18)
  }

  private var route: some View {
    HStack(spacing: 9) {
      deviceCard(
        icon: "laptopcomputer",
        title: "This Mac",
        detail: "You’re here",
        isDestination: false
      )

      Image(systemName: "arrow.right")
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 30, height: 30)
        .foregroundStyle(OtherMacStyle.coral)
        .background(OtherMacStyle.coral.opacity(0.11))
        .clipShape(Circle())
        .accessibilityHidden(true)

      deviceCard(
        icon: "desktopcomputer",
        title: "Other Mac",
        detail: "Ready",
        isDestination: true
      )
    }
    .padding(.bottom, 14)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Switch from This Mac to Other Mac")
  }

  private func deviceCard(
    icon: String,
    title: String,
    detail: String,
    isDestination: Bool
  ) -> some View {
    VStack(spacing: 5) {
      Image(systemName: icon)
        .font(.system(size: 20, weight: .medium))
        .frame(height: 22)
        .foregroundStyle(isDestination ? OtherMacStyle.coral : OtherMacStyle.ink)

      Text(title)
        .font(.system(size: 11, weight: .semibold, design: .rounded))

      Text(detail)
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(OtherMacStyle.ink.opacity(0.52))
    }
    .frame(maxWidth: .infinity)
    .frame(height: 74)
    .background(
      isDestination
        ? OtherMacStyle.coral.opacity(0.075)
        : OtherMacStyle.paper
    )
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(
          isDestination
            ? OtherMacStyle.coral.opacity(0.28)
            : OtherMacStyle.ink.opacity(0.1),
          lineWidth: 1
        )
    }
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var swapButton: some View {
    Button {
      Task {
        await model.swap()
      }
    } label: {
      ZStack {
        Text(buttonLabel)
          .font(.system(size: 16, weight: .semibold, design: .serif))
          .lineLimit(1)
          .minimumScaleFactor(0.9)
          .frame(maxWidth: .infinity)

        HStack {
          Spacer()
          if let shortcutDisplayName {
            Text(shortcutDisplayName)
              .font(.system(size: 9, weight: .semibold, design: .rounded))
              .padding(.horizontal, 7)
              .padding(.vertical, 5)
              .background(Color.white.opacity(0.17))
              .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          }
        }
      }
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity)
      .frame(height: 58)
      .foregroundStyle(Color.white)
      .background(OtherMacStyle.coral)
      .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
      .shadow(color: OtherMacStyle.coralShadow.opacity(0.78), radius: 0, y: 4)
    }
    .buttonStyle(.plain)
    .disabled(!model.isConfigured || model.swapState == .working)
    .opacity(model.isConfigured ? 1 : 0.48)
    .accessibilityHint("Switches every enabled display to its configured input.")
  }

  private var footer: some View {
    HStack {
      Button("Settings…", systemImage: "gearshape") {
        openSettings()
      }

      Spacer()

      if KeyboardShortcuts.getShortcut(for: .swapToOtherMac) == nil {
        Button("Add shortcut") {
          openSettings()
        }
      }

      Menu {
        Button("Run Setup Again…", systemImage: "sparkles") {
          openOnboarding()
        }
        Button("Hide Menu Bar Icon", systemImage: "eye.slash") {
          hideMenuBarIcon()
        }
        Divider()
        Button("Quit Other Mac", systemImage: "power") {
          NSApplication.shared.terminate(nil)
        }
      } label: {
        Image(systemName: "ellipsis")
          .frame(width: 24, height: 20)
          .contentShape(Rectangle())
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .accessibilityLabel("More options")
    }
    .buttonStyle(.plain)
    .font(.system(size: 11, weight: .medium))
    .foregroundStyle(OtherMacStyle.ink.opacity(0.65))
    .padding(.top, 16)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(OtherMacStyle.ink.opacity(0.11))
        .frame(height: 1)
    }
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
    case .working: "Switching…"
    case .success: "Switched"
    default: "Switch to Other Mac"
    }
  }

  private var shortcutDisplayName: String? {
    guard
      model.swapState == .idle,
      let shortcut = KeyboardShortcuts.getShortcut(for: .swapToOtherMac)
    else {
      return nil
    }
    return ShortcutDisplayName.make(shortcut)
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
