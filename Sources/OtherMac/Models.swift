import Foundation

enum MonitorInput: Int, CaseIterable, Codable, Identifiable, Sendable {
  case displayPort1 = 15
  case displayPort2 = 16
  case hdmi1 = 17
  case hdmi2 = 18
  case usbC = 27

  var id: Int { rawValue }

  var label: String {
    switch self {
    case .displayPort1: "DisplayPort 1"
    case .displayPort2: "DisplayPort 2"
    case .hdmi1: "HDMI 1"
    case .hdmi2: "HDMI 2"
    case .usbC: "USB-C"
    }
  }
}

struct DetectedDisplay: Identifiable, Equatable, Sendable {
  let index: Int
  let name: String
  let uuid: String

  var id: String { uuid }
}

struct DisplayConfiguration: Codable, Equatable, Sendable {
  var enabled: Bool
  var name: String
  var targetInput: Int
  var lastKnownIndex: Int
  var lastSwitchedAt: Date?

  init(
    enabled: Bool = true,
    name: String,
    targetInput: Int = MonitorInput.hdmi1.rawValue,
    lastKnownIndex: Int,
    lastSwitchedAt: Date? = nil
  ) {
    self.enabled = enabled
    self.name = name
    self.targetInput = targetInput
    self.lastKnownIndex = lastKnownIndex
    self.lastSwitchedAt = lastSwitchedAt
  }

  private enum CodingKeys: String, CodingKey {
    case enabled
    case name
    case targetInput
    case lastKnownIndex
    case lastSwitchedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    name = try container.decodeIfPresent(String.self, forKey: .name) ?? "External display"
    targetInput =
      try container.decodeIfPresent(Int.self, forKey: .targetInput)
      ?? MonitorInput.hdmi1.rawValue
    lastKnownIndex = try container.decodeIfPresent(Int.self, forKey: .lastKnownIndex) ?? 1

    do {
      lastSwitchedAt = try container.decodeIfPresent(Date.self, forKey: .lastSwitchedAt)
    } catch {
      if let value = try? container.decode(String.self, forKey: .lastSwitchedAt),
        let date = ISO8601DateFormatter().date(from: value)
      {
        lastSwitchedAt = date
      } else {
        lastSwitchedAt = nil
      }
    }
  }
}

struct AppSettings: Codable, Equatable, Sendable {
  var version: Int
  var showMenuBarIcon: Bool
  var launchAtLogin: Bool
  var completedOnboarding: Bool
  var displayConfigs: [String: DisplayConfiguration]

  init(
    version: Int = 2,
    showMenuBarIcon: Bool = true,
    launchAtLogin: Bool = false,
    completedOnboarding: Bool = false,
    displayConfigs: [String: DisplayConfiguration] = [:]
  ) {
    self.version = version
    self.showMenuBarIcon = showMenuBarIcon
    self.launchAtLogin = launchAtLogin
    self.completedOnboarding = completedOnboarding
    self.displayConfigs = displayConfigs
  }

  private enum CodingKeys: String, CodingKey {
    case version
    case showMenuBarIcon
    case showTrayIcon
    case launchAtLogin
    case completedOnboarding
    case displayConfigs
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    showMenuBarIcon =
      try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon)
      ?? container.decodeIfPresent(Bool.self, forKey: .showTrayIcon)
      ?? true
    launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    completedOnboarding =
      try container.decodeIfPresent(Bool.self, forKey: .completedOnboarding) ?? false
    displayConfigs =
      try container.decodeIfPresent(
        [String: DisplayConfiguration].self,
        forKey: .displayConfigs
      ) ?? [:]
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
    try container.encode(launchAtLogin, forKey: .launchAtLogin)
    try container.encode(completedOnboarding, forKey: .completedOnboarding)
    try container.encode(displayConfigs, forKey: .displayConfigs)
  }
}

enum SwapState: Equatable {
  case idle
  case working
  case success(displayCount: Int)
  case failure(message: String)
}
