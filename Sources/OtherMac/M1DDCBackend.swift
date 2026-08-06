import Foundation

actor M1DDCBackend: DisplayBackend {
  private let environment: [String: String]
  private var resolvedExecutable: URL?

  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    self.environment = environment
  }

  func listDisplays() async throws -> [DetectedDisplay] {
    let result = try await run(["display", "list"])
    let displays = M1DDCParser.parseDisplays(result.stdout)
    guard !displays.isEmpty else {
      throw DisplayBackendError.noDisplays
    }
    return displays
  }

  func setInput(_ input: Int, for display: DetectedDisplay) async throws {
    _ = try await run([
      "display",
      String(display.index),
      "set",
      "input",
      String(input),
    ])
  }

  private func executableURL() throws -> URL {
    if let resolvedExecutable {
      return resolvedExecutable
    }

    var candidates: [URL] = []
    if let override = environment["OTHER_MAC_M1DDC_PATH"], !override.isEmpty {
      candidates.append(URL(fileURLWithPath: override))
    }
    if let bundled = Bundle.main.resourceURL?.appendingPathComponent("m1ddc") {
      candidates.append(bundled)
    }
    if let packageResource = Bundle.module.url(forResource: "m1ddc", withExtension: nil) {
      candidates.append(packageResource)
    }
    candidates.append(contentsOf: [
      URL(fileURLWithPath: "/opt/homebrew/bin/m1ddc"),
      URL(fileURLWithPath: "/usr/local/bin/m1ddc"),
    ])

    guard
      let candidate = candidates.first(where: {
        FileManager.default.isExecutableFile(atPath: $0.path)
      })
    else {
      throw DisplayBackendError.executableNotFound
    }

    resolvedExecutable = candidate
    return candidate
  }

  private func run(_ arguments: [String]) async throws -> CommandResult {
    let executable = try executableURL()

    return try await Task.detached(priority: .userInitiated) {
      let process = Process()
      let output = Pipe()
      let errors = Pipe()

      process.executableURL = executable
      process.arguments = arguments
      process.standardOutput = output
      process.standardError = errors

      do {
        try process.run()
        process.waitUntilExit()
      } catch {
        throw DisplayBackendError.commandFailed(
          command: ([executable.lastPathComponent] + arguments).joined(separator: " "),
          message: error.localizedDescription
        )
      }

      let stdout = String(
        decoding: output.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
      ).trimmingCharacters(in: .whitespacesAndNewlines)
      let stderr = String(
        decoding: errors.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
      ).trimmingCharacters(in: .whitespacesAndNewlines)

      guard process.terminationStatus == 0 else {
        throw DisplayBackendError.commandFailed(
          command: ([executable.lastPathComponent] + arguments).joined(separator: " "),
          message: stderr.isEmpty ? stdout : stderr
        )
      }

      return CommandResult(stdout: stdout, stderr: stderr)
    }.value
  }
}

private struct CommandResult: Sendable {
  let stdout: String
  let stderr: String
}
