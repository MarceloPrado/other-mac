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
  private let launchAtLoginService: any LaunchAtLoginService
  private let isPackagedApp: Bool
  private var resetTask: Task<Void, Never>?

  init(
    backend: any DisplayBackend = M1DDCBackend(),
    store: SettingsStore = SettingsStore(),
    launchAtLoginService: any LaunchAtLoginService = SystemLaunchAtLoginService(),
    isPackagedApp: Bool = Bundle.main.bundleURL.pathExtension == "app"
  ) {
    self.backend = backend
    self.store = store
    self.launchAtLoginService = launchAtLoginService
    self.isPackagedApp = isPackagedApp
    var loadedSettings = store.load()
    if loadedSettings.version < 3 {
      loadedSettings.completedOnboarding =
        loadedSettings.completedOnboarding
        || !loadedSettings.displayConfigs.isEmpty
      loadedSettings.version = 3
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

  var applicationSupportURL: URL {
    store.applicationSupportURL
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
      if detected.count == 1, let display = detected.first {
        statusMessage = "\(display.name) is ready."
      } else {
        statusMessage = "\(detected.count) displays are ready."
      }
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
    persist()
  }

  func completeOnboarding() {
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

    guard isPackagedApp else {
      statusMessage = "Launch at login is available in the packaged app."
      return
    }

    do {
      try launchAtLoginService.setEnabled(isEnabled)
    } catch {
      settings.launchAtLogin = !isEnabled
      persist()
      statusMessage = error.localizedDescription
    }
  }

  func reconcileLaunchAtLogin() {
    guard settings.launchAtLogin, isPackagedApp else { return }
    setLaunchAtLogin(true)
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

@MainActor
protocol LaunchAtLoginService {
  func setEnabled(_ isEnabled: Bool) throws
}

struct SystemLaunchAtLoginService: LaunchAtLoginService {
  func setEnabled(_ isEnabled: Bool) throws {
    let service = SMAppService.mainApp

    if isEnabled {
      guard
        service.status != .enabled,
        service.status != .requiresApproval
      else {
        return
      }
      try service.register()
    } else {
      guard service.status != .notRegistered else { return }
      try service.unregister()
    }
  }
}
