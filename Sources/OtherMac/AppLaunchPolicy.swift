import AppKit

enum AppLaunchPolicy {
  static func shouldYieldToExistingInstance(
    currentProcessIdentifier: pid_t,
    runningProcessIdentifiers: [pid_t],
    isLifecycleSmoke: Bool
  ) -> Bool {
    guard !isLifecycleSmoke else { return false }
    return runningProcessIdentifiers.contains {
      $0 != currentProcessIdentifier
    }
  }
}

@MainActor
enum SingleInstanceController {
  static func activateExistingInstance(
    bundleIdentifier: String? = Bundle.main.bundleIdentifier,
    currentProcessIdentifier: pid_t = ProcessInfo.processInfo.processIdentifier,
    isLifecycleSmoke: Bool
  ) -> Bool {
    guard let bundleIdentifier else { return false }

    let applications = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleIdentifier
    )
    guard
      AppLaunchPolicy.shouldYieldToExistingInstance(
        currentProcessIdentifier: currentProcessIdentifier,
        runningProcessIdentifiers: applications.map(\.processIdentifier),
        isLifecycleSmoke: isLifecycleSmoke
      ),
      let existing = applications.first(where: {
        $0.processIdentifier != currentProcessIdentifier
      })
    else {
      return false
    }

    existing.activate(options: [.activateIgnoringOtherApps])
    return true
  }
}
