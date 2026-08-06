import Foundation
import Testing

@testable import OtherMac

struct SettingsStoreTests {
  @Test
  func readsTheElectronShowTrayIconSetting() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let legacyDirectory = root.appendingPathComponent(
      "zap-source-switcher",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: legacyDirectory,
      withIntermediateDirectories: true
    )
    try """
    {
      "version": 1,
      "showTrayIcon": false,
      "launchAtLogin": true,
      "displayConfigs": {
        "display-id": {
          "enabled": true,
          "name": "DELL U3223QE",
          "targetInput": 27,
          "lastKnownIndex": 1
        }
      }
    }
    """.write(
      to: legacyDirectory.appendingPathComponent("settings.json"),
      atomically: true,
      encoding: .utf8
    )

    let store = SettingsStore(applicationSupportURL: root)
    let settings = store.load()

    #expect(settings.showMenuBarIcon == false)
    #expect(settings.launchAtLogin == true)
    #expect(settings.displayConfigs["display-id"]?.targetInput == 27)

    try FileManager.default.removeItem(at: root)
  }

  @Test
  func environmentOverrideIsolatesLifecyclePreferences() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = SettingsStore(
      environment: ["OTHER_MAC_APPLICATION_SUPPORT_DIRECTORY": root.path]
    )

    try store.save(AppSettings(completedOnboarding: true))

    #expect(store.settingsURL.path.hasPrefix(root.path))
    #expect(store.load().completedOnboarding)

    try FileManager.default.removeItem(at: root)
  }
}
