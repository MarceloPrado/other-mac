import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
  static let currentOnboardingVersion = 1

  @Published private(set) var settings: AppSettings
  @Published private(set) var displays: [DetectedDisplay] = []
  @Published private(set) var swapState: SwapState = .idle
  @Published private(set) var statusMessage = "Looking for your display…"
  @Published private(set) var shortcutTestPulse = 0
  @Published private(set) var headphoneDevices: [BluetoothDevice] = []
  @Published private(set) var linkedMacNames: [String] = []
  @Published private(set) var headphoneHolder: String?
  @Published private(set) var isBringingHeadphones = false
  @Published private(set) var isHeadphoneSetupStarted = false

  private let backend: any DisplayBackend
  private let store: SettingsStore
  private let launchAtLoginService: any LaunchAtLoginService
  private let isPackagedApp: Bool
  private let pairingKeyStore: PairingKeyStore
  private let makeHeadphoneHandoff: HeadphoneHandoffFactory
  private var headphones: HeadphoneHandoff?
  private var resetTask: Task<Void, Never>?
  private var isOnboardingPresented = false
  private var shouldConsumeNextShortcutKeyUp = false

  init(
    backend: any DisplayBackend = M1DDCBackend(),
    store: SettingsStore = SettingsStore(),
    launchAtLoginService: any LaunchAtLoginService = SystemLaunchAtLoginService(),
    isPackagedApp: Bool = Bundle.main.bundleURL.pathExtension == "app",
    makeHeadphoneHandoff: @escaping HeadphoneHandoffFactory = AppModel.systemHeadphoneHandoff
  ) {
    self.pairingKeyStore = PairingKeyStore(applicationSupportURL: store.applicationSupportURL)
    self.makeHeadphoneHandoff = makeHeadphoneHandoff
    self.backend = backend
    self.store = store
    self.launchAtLoginService = launchAtLoginService
    self.isPackagedApp = isPackagedApp
    var loadedSettings = store.load()
    if loadedSettings.version < 3 {
      loadedSettings.completedOnboarding =
        loadedSettings.completedOnboarding
        || !loadedSettings.displayConfigs.isEmpty
    }
    if loadedSettings.version < 4 {
      loadedSettings.version = 4
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

  var needsOnboarding: Bool {
    settings.completedOnboardingVersion < Self.currentOnboardingVersion
  }

  var applicationSupportURL: URL {
    store.applicationSupportURL
  }

  func start() {
    if settings.headphoneAddress != nil {
      startHeadphones()
    }
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
      if settings.moveHeadphones, let address = settings.headphoneAddress {
        headphones?.send(address)
      }
      swapState = .success(displayCount: enabledDisplays.count)
      statusMessage = "See you on the other side."
      scheduleReset()
    } catch {
      swapState = .failure(message: error.localizedDescription)
      statusMessage = error.localizedDescription
    }
  }

  func handleShortcutKeyDown() {
    guard isOnboardingPresented else { return }
    shouldConsumeNextShortcutKeyUp = true
    shortcutTestPulse += 1
  }

  func handleShortcutKeyUp() async {
    if shouldConsumeNextShortcutKeyUp {
      shouldConsumeNextShortcutKeyUp = false
      return
    }
    guard !isOnboardingPresented else { return }
    await swap()
  }

  func beginOnboarding() {
    isOnboardingPresented = true
  }

  func endOnboarding() {
    isOnboardingPresented = false
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
    settings.completedOnboardingVersion = Self.currentOnboardingVersion
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

  // MARK: Headphones

  var isHeadphoneConnectedHere: Bool {
    guard let address = settings.headphoneAddress else { return false }
    return headphoneDevices.contains { $0.address == address && $0.connected }
  }

  var pairingKey: String {
    pairingKeyStore.load()
  }

  /// Starts Bluetooth and the link to the other Mac. macOS asks for both
  /// permissions here, so this only runs once headphones are wanted.
  func startHeadphones() {
    guard headphones == nil else { return }
    if settings.macID == nil {
      settings.macID = UUID().uuidString
      persist()
    }
    let handoff = makeHeadphoneHandoff(
      settings.macID ?? UUID().uuidString,
      Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
      pairingKeyStore.load()
    )
    handoff.onChange = { [weak self] in
      self?.syncHeadphones()
    }
    headphones = handoff
    isHeadphoneSetupStarted = true
    handoff.start()
    syncHeadphones()
  }

  func setHeadphone(address: String?) {
    settings.headphoneAddress = address
    settings.headphoneName = headphoneDevices.first { $0.address == address }?.name
    persist()
    syncHeadphones()
  }

  func setMoveHeadphones(_ isEnabled: Bool) {
    settings.moveHeadphones = isEnabled
    persist()
  }

  func bringHeadphonesHere() async {
    guard let address = settings.headphoneAddress, let headphones else { return }
    let name = settings.headphoneName ?? "the headphones"
    if await headphones.bring(address) {
      statusMessage = "\(name) is here."
    } else {
      statusMessage = "Couldn’t connect \(name)."
    }
  }

  /// Returns false when the text isn't a pairing key.
  func usePairingKey(_ text: String) -> Bool {
    guard let key = PairingKeyStore.normalize(text) else { return false }
    pairingKeyStore.save(key)
    headphones?.updateKey(key)
    return true
  }

  private func syncHeadphones() {
    guard let headphones else { return }
    headphoneDevices = headphones.devices.filter(\.isAudio)
    linkedMacNames = headphones.linkedMacs.values.map(\.name).sorted()
    if let address = settings.headphoneAddress {
      headphoneHolder = headphones.holder(of: address)
      isBringingHeadphones = headphones.busy.contains(address)
    } else {
      headphoneHolder = nil
      isBringingHeadphones = false
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

typealias HeadphoneHandoffFactory =
  @MainActor (_ macID: String, _ macName: String, _ pairingKey: String) -> HeadphoneHandoff

extension AppModel {
  static func systemHeadphoneHandoff(
    macID: String,
    macName: String,
    pairingKey: String
  ) -> HeadphoneHandoff {
    HeadphoneHandoff(
      bluetooth: SystemBluetoothBackend(),
      transport: PeerMesh(id: macID, name: macName, key: pairingKey),
      name: macName
    )
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
