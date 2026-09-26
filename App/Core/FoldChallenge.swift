import Foundation

struct FoldChallenge: Equatable, Sendable {
  var targets: [Double]
  static let tolerance = 5.0
  static let holdDuration = 0.350

  var isValid: Bool {
    targets.count == 3 && targets.allSatisfy { $0.isFinite && (45...135).contains($0) }
      && zip(targets, targets.dropFirst()).allSatisfy { (30...65).contains(abs($0 - $1)) }
  }

  func contains(_ angle: Double, at index: Int) -> Bool {
    abs(angle - targets[index]) <= Self.tolerance
  }

  static func generate<R: RandomNumberGenerator>(currentAngle: Double, using random: inout R) -> Self {
    let firstChoices = (45...135).filter { abs(Double($0) - currentAngle) > tolerance }
    var targets = [Double(firstChoices.randomElement(using: &random)!)]
    for _ in 1..<3 {
      let choices = (45...135).filter { (30...65).contains(abs(Double($0) - targets.last!)) }
      targets.append(Double(choices.randomElement(using: &random)!))
    }
    return Self(targets: targets)
  }
}
