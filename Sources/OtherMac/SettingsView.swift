import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      Form {
        shortcutSection
        behaviorSection
        displaysSection
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
      KeyboardShortcuts.Recorder(
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
