import Foundation

protocol DisplayBackend: Sendable {
  func listDisplays() async throws -> [DetectedDisplay]
  func setInput(_ input: Int, for display: DetectedDisplay) async throws
}

enum DisplayBackendError: LocalizedError {
  case executableNotFound
  case commandFailed(command: String, message: String)
  case noDisplays

  var errorDescription: String? {
    switch self {
    case .executableNotFound:
      """
      The display helper is missing. Rebuild the app or install m1ddc with Homebrew.
      """
    case .commandFailed(let command, let message):
      "\(command) failed: \(message)"
    case .noDisplays:
      "No DDC-capable external displays were found."
    }
  }
}
