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

    try FileManager.default.removeItem(at: root)
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
    #expect(store.load().completedOnboarding)

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
