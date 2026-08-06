import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var settings: AppSettings
  @Published private(set) var displays: [DetectedDisplay] = []
  @Published private(set) var swapState: SwapState = .idle
  @Published private(set) var statusMessage = "Looking for your display…"

  private let backend: any DisplayBackend
  private let store: SettingsStore
  private var resetTask: Task<Void, Never>?

  init(
    backend: any DisplayBackend = M1DDCBackend(),
    store: SettingsStore = SettingsStore()
  ) {
    self.backend = backend
    self.store = store
    var loadedSettings = store.load()
    if loadedSettings.version < 2 {
      loadedSettings.completedOnboarding = !loadedSettings.displayConfigs.isEmpty
      loadedSettings.version = 2
      try? store.save(loadedSettings)
    }
    settings = loadedSettings
  }

  var enabledDisplays: [DetectedDisplay] {
    displays.filter { settings.displayConfigs[$0.uuid]?.enabled == true }
  }

  var isConfigured: Bool {
    !enabledDisplays.isEmpty
  }

  func start() {
    Task {
      await refreshDisplays()
    }
  }

  func refreshDisplays() async {
    statusMessage = "Looking for your display…"

    do {
      let detected = try await backend.listDisplays()
      displays = detected

      for display in detected {
        if var existing = settings.displayConfigs[display.uuid] {
          existing.name = display.name
          existing.lastKnownIndex = display.index
          settings.displayConfigs[display.uuid] = existing
        } else {
          settings.displayConfigs[display.uuid] = DisplayConfiguration(
            name: display.name,
            lastKnownIndex: display.index
          )
        }
      }

      persist()
      statusMessage =
        detected.count == 1
        ? "\(detected[0].name) is ready."
        : "\(detected.count) displays are ready."
      swapState = .idle
    } catch {
      displays = []
      statusMessage = error.localizedDescription
      swapState = .failure(message: error.localizedDescription)
    }
  }

  func swap() async {
    guard swapState != .working else { return }
    guard !enabledDisplays.isEmpty else {
      swapState = .failure(message: DisplayBackendError.noDisplays.localizedDescription)
      return
    }

    resetTask?.cancel()
    swapState = .working

    do {
      for display in enabledDisplays {
        guard let config = settings.displayConfigs[display.uuid] else { continue }
        try await backend.setInput(config.targetInput, for: display)

        var updated = config
        updated.lastSwitchedAt = Date()
        settings.displayConfigs[display.uuid] = updated
      }

      persist()
      swapState = .success(displayCount: enabledDisplays.count)
      statusMessage = "See you on the other side."
      scheduleReset()
    } catch {
      swapState = .failure(message: error.localizedDescription)
      statusMessage = error.localizedDescription
    }
  }

  func test(display: DetectedDisplay) async {
    guard let config = settings.displayConfigs[display.uuid] else { return }

    swapState = .working
    do {
      try await backend.setInput(config.targetInput, for: display)
      swapState = .success(displayCount: 1)
      statusMessage = "Sent \(display.name) to \(inputLabel(config.targetInput))."
      scheduleReset()
    } catch {
      swapState = .failure(message: error.localizedDescription)
      statusMessage = error.localizedDescription
    }
  }

  func setDisplayEnabled(_ enabled: Bool, uuid: String) {
    guard var config = settings.displayConfigs[uuid] else { return }
    config.enabled = enabled
    settings.displayConfigs[uuid] = config
    persist()
  }

  func setTargetInput(_ input: Int, uuid: String) {
    guard var config = settings.displayConfigs[uuid] else { return }
    config.targetInput = input
    settings.displayConfigs[uuid] = config
    settings.completedOnboarding = true
    persist()
  }

  func setShowMenuBarIcon(_ isVisible: Bool) {
    settings.showMenuBarIcon = isVisible
    persist()
  }

  func setLaunchAtLogin(_ isEnabled: Bool) {
    settings.launchAtLogin = isEnabled
    persist()

    guard Bundle.main.bundleURL.pathExtension == "app" else {
      statusMessage = "Launch at login is available in the packaged app."
      return
    }

    do {
      if isEnabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      settings.launchAtLogin = !isEnabled
      persist()
      statusMessage = error.localizedDescription
    }
  }

  func inputLabel(_ value: Int) -> String {
    MonitorInput(rawValue: value)?.label ?? "Input \(value)"
  }

  private func persist() {
    do {
      try store.save(settings)
    } catch {
      statusMessage = "Couldn’t save settings: \(error.localizedDescription)"
    }
  }

  private func scheduleReset() {
    resetTask?.cancel()
    resetTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled else { return }
      self?.swapState = .idle
    }
  }
}
