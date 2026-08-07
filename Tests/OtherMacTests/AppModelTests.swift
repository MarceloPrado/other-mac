import Foundation
import Testing

@testable import OtherMac

@MainActor
struct AppModelTests {
  @Test
  func swapUsesTheDetectedIndexAndConfiguredInput() async throws {
    let backend = RecordingDisplayBackend()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = SettingsStore(applicationSupportURL: root)
    let model = AppModel(backend: backend, store: store)

    await model.refreshDisplays()
    model.setTargetInput(MonitorInput.usbC.rawValue, uuid: RecordingDisplayBackend.uuid)
    await model.swap()

    let commands = await backend.commands
    #expect(
      commands == [
        .setInput(
          input: MonitorInput.usbC.rawValue,
          displayIndex: 1,
          displayUUID: RecordingDisplayBackend.uuid
        )
      ])
    #expect(model.swapState == .success(displayCount: 1))

    try? FileManager.default.removeItem(at: root)
  }

  @Test
  func onboardingCompletionPersistsOnlyWhenFinished() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = SettingsStore(applicationSupportURL: root)
    let model = AppModel(backend: RecordingDisplayBackend(), store: store)

    await model.refreshDisplays()
    model.setTargetInput(MonitorInput.usbC.rawValue, uuid: RecordingDisplayBackend.uuid)

    #expect(!model.settings.completedOnboarding)
    #expect(!store.load().completedOnboarding)

    model.completeOnboarding()

    #expect(model.settings.completedOnboarding)
    #expect(!model.needsOnboarding)
    #expect(store.load().completedOnboarding)
    #expect(
      store.load().completedOnboardingVersion == AppModel.currentOnboardingVersion
    )

    try? FileManager.default.removeItem(at: root)
  }

  @Test
  func shortcutIsCapturedWithoutSwitchingWhileOnboardingIsPresented() async throws {
    let backend = RecordingDisplayBackend()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let model = AppModel(
      backend: backend,
      store: SettingsStore(applicationSupportURL: root)
    )
    await model.refreshDisplays()

    model.beginOnboarding()
    model.handleShortcutKeyDown()
    await model.handleShortcutKeyUp()

    #expect(model.shortcutTestPulse == 1)
    #expect(await backend.commands.isEmpty)

    model.endOnboarding()
    await model.handleShortcutKeyUp()

    #expect(await backend.commands.count == 1)

    try? FileManager.default.removeItem(at: root)
  }

  @Test
  func upgradedSettingsShowTheCurrentOnboardingOnce() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = SettingsStore(applicationSupportURL: root)
    try store.save(
      AppSettings(
        version: 3,
        completedOnboarding: true,
        displayConfigs: [
          RecordingDisplayBackend.uuid: DisplayConfiguration(
            name: "DELL U3223QE",
            targetInput: MonitorInput.usbC.rawValue,
            lastKnownIndex: 1
          )
        ]
      )
    )

    let model = AppModel(backend: RecordingDisplayBackend(), store: store)

    #expect(model.settings.version == 4)
    #expect(model.needsOnboarding)

    model.completeOnboarding()

    #expect(!model.needsOnboarding)
    #expect(!AppModel(backend: RecordingDisplayBackend(), store: store).needsOnboarding)

    try FileManager.default.removeItem(at: root)
  }

  @Test
  func configuredVersionTwoUpgradePreservesLegacyCompletion() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = SettingsStore(applicationSupportURL: root)
    try store.save(
      AppSettings(
        version: 2,
        completedOnboarding: false,
        displayConfigs: [
          RecordingDisplayBackend.uuid: DisplayConfiguration(
            name: "DELL U3223QE",
            targetInput: MonitorInput.usbC.rawValue,
            lastKnownIndex: 1
          )
        ]
      )
    )

    let model = AppModel(backend: RecordingDisplayBackend(), store: store)

    #expect(model.settings.version == 4)
    #expect(model.settings.completedOnboarding)
    #expect(model.needsOnboarding)
    #expect(store.load().version == 4)
    #expect(store.load().completedOnboarding)

    try FileManager.default.removeItem(at: root)
  }

  @Test
  func displayDetectionFailureBecomesRecoverableModelState() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let model = AppModel(
      backend: FailingDisplayBackend(),
      store: SettingsStore(applicationSupportURL: root)
    )

    await model.refreshDisplays()

    #expect(model.displays.isEmpty)
    #expect(
      model.swapState
        == .failure(message: DisplayBackendError.noDisplays.localizedDescription)
    )
    #expect(model.statusMessage == DisplayBackendError.noDisplays.localizedDescription)

    try? FileManager.default.removeItem(at: root)
  }

  @Test
  func launchAtLoginFailureRollsBackThePreference() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let service = RecordingLaunchAtLoginService(error: TestLaunchAtLoginError.denied)
    let store = SettingsStore(applicationSupportURL: root)
    let model = AppModel(
      backend: RecordingDisplayBackend(),
      store: store,
      launchAtLoginService: service,
      isPackagedApp: true
    )

    model.setLaunchAtLogin(true)

    #expect(!model.settings.launchAtLogin)
    #expect(!store.load().launchAtLogin)
    #expect(model.statusMessage == TestLaunchAtLoginError.denied.localizedDescription)

    try FileManager.default.removeItem(at: root)
  }

  @Test
  func upgradeLaunchAtLoginPreferenceIsReconciled() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = SettingsStore(applicationSupportURL: root)
    try store.save(AppSettings(launchAtLogin: true, completedOnboarding: true))
    let service = RecordingLaunchAtLoginService()
    let model = AppModel(
      backend: RecordingDisplayBackend(),
      store: store,
      launchAtLoginService: service,
      isPackagedApp: true
    )

    model.reconcileLaunchAtLogin()

    #expect(service.values == [true])
    #expect(model.settings.launchAtLogin)

    try FileManager.default.removeItem(at: root)
  }
}

private actor RecordingDisplayBackend: DisplayBackend {
  static let uuid = "7406FFA1-7562-4A2F-B764-55FAA7E45CCF"

  enum Command: Equatable, Sendable {
    case setInput(input: Int, displayIndex: Int, displayUUID: String)
  }

  private(set) var commands: [Command] = []

  func listDisplays() async throws -> [DetectedDisplay] {
    [
      DetectedDisplay(
        index: 1,
        name: "DELL U3223QE",
        uuid: Self.uuid
      )
    ]
  }

  func setInput(_ input: Int, for display: DetectedDisplay) async throws {
    commands.append(
      .setInput(
        input: input,
        displayIndex: display.index,
        displayUUID: display.uuid
      )
    )
  }
}

private actor FailingDisplayBackend: DisplayBackend {
  func listDisplays() async throws -> [DetectedDisplay] {
    throw DisplayBackendError.noDisplays
  }

  func setInput(_ input: Int, for display: DetectedDisplay) async throws {
    throw DisplayBackendError.noDisplays
  }
}

@MainActor
private final class RecordingLaunchAtLoginService: LaunchAtLoginService {
  private(set) var values: [Bool] = []
  private let error: Error?

  init(error: Error? = nil) {
    self.error = error
  }

  func setEnabled(_ isEnabled: Bool) throws {
    values.append(isEnabled)
    if let error {
      throw error
    }
  }
}

private enum TestLaunchAtLoginError: LocalizedError {
  case denied

  var errorDescription: String? {
    "Launch at login was denied."
  }
}
