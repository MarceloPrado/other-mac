import Testing

@testable import OtherMac

struct OnboardingFlowTests {
  @Test
  func movesThroughThreeStepsWithoutPassingEitherEnd() {
    var flow = OnboardingFlow()

    #expect(flow.step == .welcome)
    #expect(!flow.canGoBack)
    #expect(!flow.isLastStep)

    flow.goBack()
    #expect(flow.step == .welcome)

    flow.advance()
    #expect(flow.step == .display)
    #expect(flow.canGoBack)

    flow.advance()
    #expect(flow.step == .shortcut)
    #expect(flow.isLastStep)

    flow.advance()
    #expect(flow.step == .shortcut)

    flow.goBack()
    #expect(flow.step == .display)
  }
}
