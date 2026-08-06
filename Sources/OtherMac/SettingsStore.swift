import Foundation

struct SettingsStore {
  let fileManager: FileManager
  let applicationSupportURL: URL

  init(
    fileManager: FileManager = .default,
    applicationSupportURL: URL? = nil
  ) {
    self.fileManager = fileManager
    self.applicationSupportURL =
      applicationSupportURL
      ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
  }

  var settingsURL: URL {
    applicationSupportURL
      .appendingPathComponent("Other Mac", isDirectory: true)
      .appendingPathComponent("settings.json")
  }

  private var legacyURLs: [URL] {
    [
      applicationSupportURL
        .appendingPathComponent("zap-source-switcher", isDirectory: true)
        .appendingPathComponent("settings.json"),
      applicationSupportURL
        .appendingPathComponent("Zap", isDirectory: true)
        .appendingPathComponent("settings.json"),
    ]
  }

  func load() -> AppSettings {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    for url in [settingsURL] + legacyURLs {
      guard
        let data = try? Data(contentsOf: url),
        let settings = try? decoder.decode(AppSettings.self, from: data)
      else {
        continue
      }
      return settings
    }

    return AppSettings()
  }

  func save(_ settings: AppSettings) throws {
    let directory = settingsURL.deletingLastPathComponent()
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(settings).write(to: settingsURL, options: .atomic)
  }
}
