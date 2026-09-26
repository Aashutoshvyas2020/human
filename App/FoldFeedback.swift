import SwiftUI

struct FoldFeedback {
  private(set) var step = 0
  private(set) var hold = 0
  mutating func completeStep() { step += 1 }
  mutating func enterHold() { hold += 1 }
}

struct FoldFeedbackModifier: ViewModifier {
  var feedback: FoldFeedback
  func body(content: Content) -> some View {
    content
      .sensoryFeedback(.impact(weight: .medium, intensity: 0.65), trigger: feedback.step)
      .sensoryFeedback(.impact(weight: .light, intensity: 0.35), trigger: feedback.hold)
  }
}
