import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel
  let openOnboarding: () -> Void
  let checkForUpdates: () -> Void
  @State private var pairingKeyNote: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      Form {
        shortcutSection
        behaviorSection
        displaysSection
        headphonesSection
        hardwareSection
      }
      .formStyle(.grouped)
    }
    .frame(minWidth: 520, minHeight: 560)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var header: some View {
    HStack(spacing: 14) {
      Image(nsImage: NSApplication.shared.applicationIconImage)
        .resizable()
        .frame(width: 54, height: 54)
      VStack(alignment: .leading, spacing: 3) {
        Text("Other Mac")
          .font(.system(size: 24, weight: .medium, design: .serif))
        Text("One keystroke to the other side.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Refresh", systemImage: "arrow.clockwise") {
        Task {
          await model.refreshDisplays()
        }
      }
    }
    .padding(20)
  }

  private var shortcutSection: some View {
    Section("Keyboard") {
      ShortcutRecorder(
        "Swap to the other Mac",
        name: .swapToOtherMac
      )
      Text("The shortcut works globally, even when the icon is hidden.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var behaviorSection: some View {
    Section("Behavior") {
      Toggle(
        "Show in menu bar",
        isOn: Binding(
          get: { model.settings.showMenuBarIcon },
          set: { isVisible in
            model.setShowMenuBarIcon(isVisible)
          }
        )
      )
      Text("Open Other Mac from Finder or Spotlight to bring the icon back.")
        .font(.caption)
        .foregroundStyle(.secondary)

      Toggle(
        "Open at login",
        isOn: Binding(
          get: { model.settings.launchAtLogin },
          set: { isEnabled in
            model.setLaunchAtLogin(isEnabled)
          }
        )
      )

      Button("Run Setup Again…") {
        openOnboarding()
      }
      Text("Review the monitor, input, and shortcut for this Mac.")
        .font(.caption)
        .foregroundStyle(.secondary)

      Button("Check for Updates…") {
        checkForUpdates()
      }
      Text("Other Mac also checks periodically and will offer new releases automatically.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var displaysSection: some View {
    Section("Displays") {
      if model.displays.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("No external display found")
            .fontWeight(.medium)
          Text(model.statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } else {
        ForEach(model.displays) { display in
          displayRow(display)
        }
      }
    }
  }

  private func displayRow(_ display: DetectedDisplay) -> some View {
    let config = model.settings.displayConfigs[display.uuid]

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Toggle(
          display.name,
          isOn: Binding(
            get: { config?.enabled ?? true },
            set: { model.setDisplayEnabled($0, uuid: display.uuid) }
          )
        )
        Spacer()
        Text("Display \(display.index)")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
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
      }
    }
    .padding(.vertical, 5)
  }

  @ViewBuilder
  private var headphonesSection: some View {
    Section("Headphones") {
      if !model.isHeadphoneSetupStarted {
        Button("Set Up Headphones…") {
          model.startHeadphones()
        }
        Text(
          "Send Bluetooth headphones to the other Mac along with the display. macOS will ask for Bluetooth and local network access."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      } else {
        Picker(
          "Headphones",
          selection: Binding(
            get: { model.settings.headphoneAddress },
            set: { model.setHeadphone(address: $0) }
          )
        ) {
          Text("None").tag(String?.none)
          ForEach(headphoneChoices) { device in
            Text(device.name).tag(String?.some(device.address))
          }
        }

        Toggle(
          "Move with the display",
          isOn: Binding(
            get: { model.settings.moveHeadphones },
            set: { model.setMoveHeadphones($0) }
          )
        )
        .disabled(model.settings.headphoneAddress == nil)
        Text("Turn this off to look at the other Mac while your audio stays here.")
          .font(.caption)
          .foregroundStyle(.secondary)

        LabeledContent("Other Mac") {
          Text(
            model.linkedMacNames.isEmpty
              ? "Not linked"
              : model.linkedMacNames.joined(separator: ", ")
          )
          .foregroundStyle(.secondary)
        }

        HStack {
          Button("Copy Pairing Key") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(model.pairingKey, forType: .string)
            pairingKeyNote = "Copied. Paste it into Other Mac on your other Mac."
          }
          Button("Paste Pairing Key") {
            let pasted = NSPasteboard.general.string(forType: .string) ?? ""
            pairingKeyNote =
              model.usePairingKey(pasted)
              ? "Pairing key saved."
              : "The clipboard doesn’t hold a pairing key."
          }
        }
        Text(
          pairingKeyNote
            ?? "Both Macs need Other Mac open, the headphones paired, and the same pairing key."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
  }

  /// Paired audio devices, plus the saved choice if it is no longer paired.
  private var headphoneChoices: [BluetoothDevice] {
    var choices = model.headphoneDevices
    if let address = model.settings.headphoneAddress,
      !choices.contains(where: { $0.address == address })
    {
      choices.append(
        BluetoothDevice(
          address: address,
          name: model.settings.headphoneName ?? address,
          connected: false,
          isAudio: true
        )
      )
    }
    return choices
  }

  private var hardwareSection: some View {
    Section {
      Label {
        Text(
          "For the keyboard and mouse to follow, configure your monitor’s USB/KVM to follow its active input, or use peripherals paired with both Macs."
        )
      } icon: {
        Image(systemName: "keyboard")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }
}
