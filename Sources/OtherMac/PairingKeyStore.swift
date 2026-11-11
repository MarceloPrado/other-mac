import Foundation

/// The secret both Macs share. Kept in a 0600 file rather than the Keychain:
/// the ad hoc signature changes with every update, and each change would make
/// the Keychain ask for the login password again.
struct PairingKeyStore {
  let url: URL

  init(applicationSupportURL: URL) {
    url =
      applicationSupportURL
      .appendingPathComponent("Other Mac", isDirectory: true)
      .appendingPathComponent("pairing-key")
  }

  /// The stored key, created on first use.
  func load() -> String {
    if let stored = try? String(contentsOf: url, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines),
      Self.isValid(stored)
    {
      return stored
    }
    let key = Self.generate()
    save(key)
    return key
  }

  func save(_ key: String) {
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    // Replace rather than overwrite so the mode applies to an existing file too.
    try? FileManager.default.removeItem(at: url)
    FileManager.default.createFile(
      atPath: url.path,
      contents: Data(key.utf8),
      attributes: [.posixPermissions: 0o600]
    )
  }

  /// Accepts what a person pastes: any case, surrounding whitespace.
  static func normalize(_ text: String) -> String? {
    let key = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return isValid(key) ? key : nil
  }

  static func isValid(_ key: String) -> Bool {
    key.count == 32 && key.allSatisfy { $0.isHexDigit && !$0.isUppercase }
  }

  static func generate() -> String {
    (0..<16).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
  }
}
