import Foundation
import Testing

@testable import OtherMac

struct AppLaunchPolicyTests {
  @Test
  func yieldsWhenAnotherAppInstanceIsAlreadyRunning() {
    #expect(
      AppLaunchPolicy.shouldYieldToExistingInstance(
        currentProcessIdentifier: 42,
        runningProcessIdentifiers: [42, 84],
        isLifecycleSmoke: false
      )
    )
  }

  @Test
  func allowsTheOnlyRunningAppInstance() {
    #expect(
      !AppLaunchPolicy.shouldYieldToExistingInstance(
        currentProcessIdentifier: 42,
        runningProcessIdentifiers: [42],
        isLifecycleSmoke: false
      )
    )
  }

  @Test
  func lifecycleSmokeCanRunBesideTheInstalledApp() {
    #expect(
      !AppLaunchPolicy.shouldYieldToExistingInstance(
        currentProcessIdentifier: 42,
        runningProcessIdentifiers: [42, 84],
        isLifecycleSmoke: true
      )
    )
  }
}
