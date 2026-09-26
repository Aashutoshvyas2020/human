import Foundation

struct FoldChallenge: Equatable, Sendable {
  var targets: [Double]
  static let tolerance = 5.0
  static let holdDuration = 0.800
  // Tolerance never accepts a hinge angle below 130 degrees.
  static let targetRange = 135...175
  static let targetSeparation = 30.0...40.0

  var isValid: Bool {
    targets.count == 3 && targets.allSatisfy { $0.isFinite && (135...175).contains($0) }
      && zip(targets, targets.dropFirst()).allSatisfy { Self.targetSeparation.contains(abs($0 - $1)) }
  }

  func contains(_ angle: Double, at index: Int) -> Bool {
    abs(angle - targets[index]) <= Self.tolerance
  }

  static func generate<R: RandomNumberGenerator>(currentAngle: Double, using random: inout R) -> Self {
    let firstChoices = targetRange.filter { candidate in
      abs(Double(candidate) - currentAngle) > tolerance
        && targetRange.contains { neighbor in
          targetSeparation.contains(abs(Double(candidate - neighbor)))
        }
    }
    var targets = [Double(firstChoices.randomElement(using: &random)!)]
    for _ in 1..<3 {
      let choices = targetRange.filter { targetSeparation.contains(abs(Double($0) - targets.last!)) }
      targets.append(Double(choices.randomElement(using: &random)!))
    }
    return Self(targets: targets)
  }
}
