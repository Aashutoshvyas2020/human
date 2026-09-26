import Foundation

/// Pure event reducer. Times are monotonic seconds supplied by capture or a test clock.
struct ChallengeStateMachine: Sendable {
  var challenge: FoldChallenge
  private(set) var step = 0
  private(set) var accumulatedHold: TimeInterval = 0
  private(set) var holdEnteredAt: TimeInterval?
  private(set) var completionTime: TimeInterval?

  var isComplete: Bool { completionTime != nil }

  func holdElapsed(at time: TimeInterval) -> TimeInterval {
    min(FoldChallenge.holdDuration, accumulatedHold + (holdEnteredAt.map { max(0, time - $0) } ?? 0))
  }

  mutating func receive(_ sample: HingeSample) {
    guard !isComplete else { return }
    // Resolve a deadline preceding this event before changing the last-known range state.
    advanceTime(to: sample.timestamp)
    guard !isComplete else { return }
    if step < 2 {
      if challenge.contains(sample.angle, at: step) { step += 1 }
    } else if challenge.contains(sample.angle, at: 2) {
      if holdEnteredAt == nil { holdEnteredAt = sample.timestamp }
    } else if let entry = holdEnteredAt {
      accumulatedHold += max(0, sample.timestamp - entry)
      holdEnteredAt = nil
    }
  }

  mutating func advanceTime(to time: TimeInterval) {
    guard !isComplete, let entry = holdEnteredAt else { return }
    let deadline = entry + FoldChallenge.holdDuration - accumulatedHold
    if time >= deadline {
      completionTime = deadline
      step = 3
    }
  }
}
