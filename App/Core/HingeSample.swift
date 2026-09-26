import Foundation

struct HingeSample: Equatable, Sendable {
  var timestamp: TimeInterval
  var angle: Double
}

struct FoldTrace: Sendable {
  var samples: [HingeSample] = []
  var startedAt: TimeInterval
  var completedAt: TimeInterval?
  var interruptedAt: TimeInterval?
}
