import Foundation

struct TrajectoryValidator: Sendable {
  struct Policy: Sendable {
    // Provisional permissive limit. Calibrate from physical Duo measurements.
    var maximumAngularSpeed = 1_440.0
  }

  enum Failure: String, Error {
    case invalidChallenge, invalidReading, invalidTimestamp, incomplete, interrupted
    case implausibleMotion, missingIntermediateReading
  }

  var policy = Policy()

  func validate(_ trace: FoldTrace, challenge: FoldChallenge) -> Result<Void, Failure> {
    guard challenge.isValid else { return .failure(.invalidChallenge) }
    guard trace.interruptedAt == nil else { return .failure(.interrupted) }
    guard let end = trace.completedAt, end.isFinite, trace.startedAt.isFinite,
      end >= trace.startedAt, !trace.samples.isEmpty else { return .failure(.incomplete) }
    var replay = ChallengeStateMachine(challenge: challenge)
    var previous: HingeSample?
    var sawIntermediate = false
    var enteredFinalTarget = false
    for sample in trace.samples {
      guard sample.angle.isFinite, (0...180).contains(sample.angle) else { return .failure(.invalidReading) }
      guard sample.timestamp.isFinite, sample.timestamp >= trace.startedAt,
        sample.timestamp <= end else { return .failure(.invalidTimestamp) }
      if let previous {
        let elapsed = sample.timestamp - previous.timestamp
        guard elapsed > 0 else { return .failure(.invalidTimestamp) }
        guard abs(sample.angle - previous.angle) / elapsed <= policy.maximumAngularSpeed else {
          return .failure(.implausibleMotion)
        }
      }
      let step = replay.step
      if step == 1 || (step == 2 && !enteredFinalTarget) {
        let lower = min(challenge.targets[step - 1], challenge.targets[step]) + FoldChallenge.tolerance
        let upper = max(challenge.targets[step - 1], challenge.targets[step]) - FoldChallenge.tolerance
        if sample.angle > lower && sample.angle < upper { sawIntermediate = true }
        if challenge.contains(sample.angle, at: step) {
          guard sawIntermediate else { return .failure(.missingIntermediateReading) }
          if step == 2 { enteredFinalTarget = true }
        }
      }
      replay.receive(sample)
      if replay.step != step { sawIntermediate = false }
      previous = sample
    }
    replay.advanceTime(to: end)
    return replay.isComplete ? .success(()) : .failure(.incomplete)
  }
}
