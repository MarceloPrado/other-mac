import KeyboardShortcuts
import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: AppModel
  let finish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var flow = OnboardingFlow()
  @State private var isHopping = false
  @State private var hasShortcut =
    KeyboardShortcuts.getShortcut(for: .swapToOtherMac) != nil

  var body: some View {
    VStack(spacing: 0) {
      topBar

      ZStack {
        currentStep
          .id(flow.step)
          .transition(stepTransition)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()

      navigation
    }
    .frame(width: 620, height: 560)
    .background(OtherMacStyle.parchment)
    .foregroundStyle(OtherMacStyle.ink)
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
        isHopping = true
      }
    }
  }

  private var topBar: some View {
    HStack(spacing: 12) {
      Image(nsImage: NSApplication.shared.applicationIconImage)
        .resizable()
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)

      Text("Other Mac")
        .font(.system(size: 13, weight: .semibold, design: .rounded))

      Spacer()

      HStack(spacing: 7) {
        ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
          Capsule()
            .fill(
              step == flow.step
                ? OtherMacStyle.coral
                : OtherMacStyle.ink.opacity(0.16)
            )
            .frame(width: step == flow.step ? 22 : 7, height: 7)
        }
      }
      .animation(reduceMotion ? nil : .spring(response: 0.35), value: flow.step)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        "Step \(flow.step.rawValue + 1) of \(OnboardingStep.allCases.count)"
      )
    }
    .padding(.horizontal, 28)
    .padding(.top, 22)
  }

  @ViewBuilder
  private var currentStep: some View {
    switch flow.step {
    case .welcome:
      welcomeStep
    case .display:
      displayStep
    case .shortcut:
      shortcutStep
    }
  }

  private var welcomeStep: some View {
    VStack(spacing: 22) {
      Spacer()

      macHop

      VStack(spacing: 10) {
        Text("Meet your Other Mac.")
          .modifier(EditorialTitle())
          .multilineTextAlignment(.center)

        Text(
          "Install Other Mac on both Macs. You’ll run this quick setup once on each one."
        )
        .font(.system(size: 15))
        .foregroundStyle(OtherMacStyle.secondaryInk)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 410)
        .fixedSize(horizontal: false, vertical: true)
      }

      Label("No account or cloud setup needed.", systemImage: "checkmark.circle.fill")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(OtherMacStyle.secondaryInk)

      Spacer()
    }
    .padding(.horizontal, 52)
  }

  private var macHop: some View {
    HStack(spacing: 26) {
      deviceTile(label: "This Mac")

      Image(systemName: "arrow.right")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(OtherMacStyle.coral)
        .offset(y: isHopping ? -6 : 2)
        .accessibilityHidden(true)

      deviceTile(label: "Other Mac")
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("This Mac and your other Mac")
  }

  private func deviceTile(label: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: "laptopcomputer")
        .font(.system(size: 35, weight: .light))
      Text(label)
        .font(.system(size: 11, weight: .semibold, design: .rounded))
    }
    .frame(width: 112, height: 86)
    .background(OtherMacStyle.paper)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(OtherMacStyle.ink.opacity(0.1))
    }
  }

  private var displayStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 7) {
        Text("Choose the other side.")
          .modifier(EditorialTitle())
        Text(
          "On this Mac, choose the monitor and the input connected to your other Mac."
        )
        .font(.system(size: 14))
        .foregroundStyle(OtherMacStyle.secondaryInk)
      }

      Group {
        if model.displays.isEmpty {
          emptyDisplays
        } else {
          ScrollView {
            VStack(spacing: 10) {
              ForEach(model.displays) { display in
                onboardingDisplayRow(display)
              }
            }
          }
          .scrollIndicators(.never)
        }
      }
      .frame(maxHeight: 230)

      Label(
        "For keyboard and mouse, set your monitor’s USB/KVM to follow the active input.",
        systemImage: "keyboard"
      )
      .font(.system(size: 11))
      .foregroundStyle(OtherMacStyle.secondaryInk)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 56)
    .padding(.top, 30)
  }

  private var emptyDisplays: some View {
    VStack(spacing: 10) {
      Image(systemName: "display.trianglebadge.exclamationmark")
        .font(.system(size: 29, weight: .light))
      Text("No external display found")
        .font(.system(size: 14, weight: .semibold))
      Text(model.statusMessage)
        .font(.system(size: 11))
        .foregroundStyle(OtherMacStyle.secondaryInk)
        .multilineTextAlignment(.center)
        .lineLimit(3)
      Button("Look Again", systemImage: "arrow.clockwise") {
        Task {
          await model.refreshDisplays()
        }
      }
      .buttonStyle(SecondaryOnboardingButtonStyle())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(18)
    .background(OtherMacStyle.paper)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func onboardingDisplayRow(_ display: DetectedDisplay) -> some View {
    let config = model.settings.displayConfigs[display.uuid]

    return VStack(spacing: 12) {
      HStack {
        Toggle(
          display.name,
          isOn: Binding(
            get: { config?.enabled ?? true },
            set: { model.setDisplayEnabled($0, uuid: display.uuid) }
          )
        )
        .toggleStyle(.checkbox)
        .font(.system(size: 13, weight: .semibold))

        Spacer()

        Text("Display \(display.index)")
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(OtherMacStyle.secondaryInk)
      }

      HStack {
        Picker(
          "Other Mac input",
          selection: Binding(
            get: { config?.targetInput ?? MonitorInput.hdmi1.rawValue },
            set: { model.setTargetInput($0, uuid: display.uuid) }
          )
        ) {
          ForEach(MonitorInput.allCases) { input in
            Text(input.label).tag(input.rawValue)
          }
        }
        .frame(maxWidth: 300)

        Spacer()

        Button("Test") {
          Task {
            await model.test(display: display)
          }
        }
        .buttonStyle(SecondaryOnboardingButtonStyle())
        .disabled(config?.enabled == false || model.swapState == .working)
      }
    }
    .padding(15)
    .background(OtherMacStyle.paper)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(OtherMacStyle.ink.opacity(0.1))
    }
  }

  private var shortcutStep: some View {
    VStack(spacing: 22) {
      Spacer()

      Image(systemName: "command.square")
        .font(.system(size: 54, weight: .light))
        .foregroundStyle(OtherMacStyle.coral)
        .accessibilityHidden(true)

      VStack(spacing: 9) {
        Text("One shortcut. Two Macs.")
          .modifier(EditorialTitle())
          .multilineTextAlignment(.center)
        Text(
          "Record a global shortcut for swapping. You can use the same shortcut on both Macs."
        )
        .font(.system(size: 14))
        .foregroundStyle(OtherMacStyle.secondaryInk)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
      }

      KeyboardShortcuts.Recorder(
        "Swap to the other Mac",
        name: .swapToOtherMac,
        onChange: { shortcut in
          hasShortcut = shortcut != nil
        }
      )
      .padding(16)
      .background(OtherMacStyle.paper)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

      Text("Remember to finish setup on your other Mac, too.")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(OtherMacStyle.secondaryInk)

      Spacer()
    }
    .padding(.horizontal, 70)
  }

  private var navigation: some View {
    HStack {
      if flow.canGoBack {
        Button("Back") {
          goBack()
        }
        .buttonStyle(SecondaryOnboardingButtonStyle())
      } else {
        Color.clear
          .frame(width: 74, height: 38)
      }

      Spacer()

      Button(flow.isLastStep ? "Finish Setup" : "Continue") {
        if flow.isLastStep {
          finish()
        } else {
          advance()
        }
      }
      .buttonStyle(PrimaryOnboardingButtonStyle())
      .disabled(
        (flow.step == .display && !model.isConfigured)
          || (flow.step == .shortcut && !hasShortcut)
      )
      .accessibilityHint(
        continueAccessibilityHint
      )
    }
    .padding(.horizontal, 28)
    .padding(.bottom, 24)
  }

  private var stepTransition: AnyTransition {
    guard !reduceMotion else {
      return .opacity
    }
    return .asymmetric(
      insertion: .move(edge: .trailing).combined(with: .opacity),
      removal: .move(edge: .leading).combined(with: .opacity)
    )
  }

  private var continueAccessibilityHint: String {
    if flow.step == .display && !model.isConfigured {
      return "Choose at least one display first."
    }
    if flow.step == .shortcut && !hasShortcut {
      return "Record a global shortcut first."
    }
    return ""
  }

  private func advance() {
    withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) {
      flow.advance()
    }
  }

  private func goBack() {
    withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) {
      flow.goBack()
    }
  }
}

private struct PrimaryOnboardingButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .semibold, design: .rounded))
      .foregroundStyle(.white)
      .padding(.horizontal, 22)
      .frame(height: 38)
      .background(OtherMacStyle.coral)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      .shadow(
        color: isEnabled ? OtherMacStyle.coralShadow.opacity(0.72) : .clear,
        radius: 0,
        y: configuration.isPressed ? 1 : 3
      )
      .offset(y: configuration.isPressed ? 2 : 0)
      .opacity(isEnabled ? 1 : 0.45)
  }
}

private struct SecondaryOnboardingButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold, design: .rounded))
      .foregroundStyle(OtherMacStyle.ink.opacity(configuration.isPressed ? 0.55 : 0.78))
      .padding(.horizontal, 14)
      .frame(height: 34)
      .background(OtherMacStyle.ink.opacity(configuration.isPressed ? 0.1 : 0.06))
      .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
  }
}
