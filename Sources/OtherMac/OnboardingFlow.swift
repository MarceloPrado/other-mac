enum OnboardingStep: Int, CaseIterable, Equatable {
  case welcome
  case display
  case shortcut
}

struct OnboardingFlow: Equatable {
  private(set) var step: OnboardingStep = .welcome

  var canGoBack: Bool {
    step != .welcome
  }

  var isLastStep: Bool {
    step == .shortcut
  }

  mutating func advance() {
    guard
      let next = OnboardingStep(rawValue: step.rawValue + 1)
    else {
      return
    }
    step = next
  }

  mutating func goBack() {
    guard
      let previous = OnboardingStep(rawValue: step.rawValue - 1)
    else {
      return
    }
    step = previous
  }
}
