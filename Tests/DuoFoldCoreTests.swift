import XCTest
@testable import DuoFoldCore

final class DuoFoldCoreTests: XCTestCase {
  let challenge = FoldChallenge(targets: [135, 170, 135])
  let validator = TrajectoryValidator()

  func trace(_ values: [(Double, Double)], end: Double = 1.2) -> FoldTrace {
    FoldTrace(samples: values.map { HingeSample(timestamp: $0.0, angle: $0.1) }, startedAt: 0, completedAt: end)
  }
  var valid: FoldTrace { trace([(0.1, 135), (0.3, 152.5), (0.5, 170), (0.7, 152.5), (0.8, 135)]) }
  func assertValid(_ trace: FoldTrace, file: StaticString = #filePath, line: UInt = #line) {
    if case .failure(let reason) = validator.validate(trace, challenge: challenge) {
      XCTFail("Unexpected rejection: \(reason)", file: file, line: line)
    }
  }
  func assertFailure(_ trace: FoldTrace, _ expected: TrajectoryValidator.Failure, file: StaticString = #filePath, line: UInt = #line) {
    guard case .failure(let actual) = validator.validate(trace, challenge: challenge) else {
      XCTFail("Expected \(expected)", file: file, line: line); return
    }
    XCTAssertEqual(actual, expected, file: file, line: line)
  }

  func testValidStationaryHoldWithoutRepeatedCallbacks() { assertValid(valid) }
  func testExactToleranceBoundaries() {
    assertValid(trace([(0.1, 130), (0.3, 152.5), (0.5, 175), (0.7, 152.5), (0.8, 140)]))
  }
  func testOutsideTolerance() {
    assertFailure(trace([(0.1, 129.99), (0.3, 152.5), (0.5, 170), (0.7, 152.5), (0.8, 135)]), .incomplete)
  }
  func testIncorrectOrder() {
    assertFailure(trace([(0.1, 170), (0.3, 152.5), (0.5, 135), (0.7, 152.5), (0.8, 135)]), .incomplete)
  }
  func testOvershootAndCorrection() {
    assertValid(trace([(0.1, 145), (0.2, 130), (0.3, 135), (0.4, 152.5), (0.5, 180), (0.6, 170), (0.7, 152.5), (0.8, 135)]))
  }
  func testAccumulatedHoldPausesOutsideRange() {
    var value = valid
    value.samples += [HingeSample(timestamp: 0.95, angle: 145), HingeSample(timestamp: 1.5, angle: 135)]
    value.completedAt = 1.71
    assertValid(value)
    value.completedAt = 1.69
    assertFailure(value, .incomplete)
  }
  func testMissingIntermediateReadingRejectedDespitePlausibleSpeed() {
    assertFailure(trace([(0.1, 135), (0.5, 170), (0.7, 152.5), (0.8, 135)]), .missingIntermediateReading)
  }
  func testSparseCallbacksAndLargeAdjacentAnglesAllowed() {
    assertValid(trace([(0.01, 135), (0.4, 160), (0.7, 170), (1.0, 145), (1.3, 135)], end: 1.7))
  }
  func testImpossibleJump() {
    assertFailure(trace([(0.1, 135), (0.101, 152.5), (0.5, 170), (0.7, 152.5), (0.8, 135)]), .implausibleMotion)
  }
  func testNonIncreasingTimestamps() {
    for time in [0.1, 0.09] {
      assertFailure(trace([(0.1, 135), (time, 152.5), (0.5, 170), (0.7, 152.5), (0.8, 135)]), .invalidTimestamp)
    }
  }
  func testIncompleteAndInterruptedCapture() {
    var value = valid
    value.completedAt = 1.0
    assertFailure(value, .incomplete)
    value.completedAt = nil
    assertFailure(value, .incomplete)
    value.completedAt = 1.2
    value.interruptedAt = 0.9
    assertFailure(value, .interrupted)
  }
  func testClockBoundaryAndHoldExit() {
    var machine = ChallengeStateMachine(challenge: challenge)
    for sample in valid.samples { machine.receive(sample) }
    machine.advanceTime(to: 1.149)
    XCTAssertFalse(machine.isComplete)
    machine.advanceTime(to: 1.15)
    XCTAssertTrue(machine.isComplete)
  }
  func testGeneratorConstraintsAcrossStartingAngles() {
    var random = SystemRandomNumberGenerator()
    for angle in stride(from: 0.0, through: 180.0, by: 1) {
      for _ in 0..<10 {
        let value = FoldChallenge.generate(currentAngle: angle, using: &random)
        XCTAssertTrue(value.isValid)
        XCTAssertTrue(value.targets.allSatisfy { $0 >= 135 && $0 <= 175 })
        XCTAssertTrue(value.targets.allSatisfy { $0 - FoldChallenge.tolerance >= 130 })
        XCTAssertGreaterThan(abs(value.targets[0] - angle), 5)
      }
    }
  }
  func testGeneratedChallengesReplayCleanlyAcrossManyAttempts() {
    var random = SeededRandom(state: 0xD00F01D)
    for attempt in 0..<500 {
      let initialAngle = Double(attempt % 181)
      let challenge = FoldChallenge.generate(currentAngle: initialAngle, using: &random)
      var samples: [HingeSample] = []
      var time = 0.1
      for index in challenge.targets.indices {
        if index > 0 {
          samples.append(HingeSample(timestamp: time,
            angle: (challenge.targets[index - 1] + challenge.targets[index]) / 2))
          time += 0.1
        }
        samples.append(HingeSample(timestamp: time, angle: challenge.targets[index]))
        time += 0.1
      }
      let trace = FoldTrace(samples: samples, startedAt: 0,
        completedAt: samples.last!.timestamp + FoldChallenge.holdDuration)
      if case .failure(let reason) = validator.validate(trace, challenge: challenge) {
        XCTFail("Attempt \(attempt) rejected: \(reason)")
      }
    }
  }
  func testPausedClockNeverEarnsDwellAndFreshAttemptIgnoresOldDeadline() {
    var machine = ChallengeStateMachine(challenge: challenge)
    for sample in valid.samples { machine.receive(sample) }
    machine.receive(HingeSample(timestamp: 0.9, angle: 145))
    machine.advanceTime(to: 100)
    XCTAssertFalse(machine.isComplete)
    XCTAssertEqual(machine.holdElapsed(at: 100), 0.1, accuracy: 0.000001)
    machine = ChallengeStateMachine(challenge: challenge)
    machine.advanceTime(to: 101)
    XCTAssertFalse(machine.isComplete)
    XCTAssertEqual(machine.step, 0)
    XCTAssertEqual(machine.holdElapsed(at: 101), 0)
  }
  func testInvalidCompletionAndNonFiniteTimestamps() {
    var value = valid
    value.completedAt = 0.6
    assertFailure(value, .invalidTimestamp)
    value = valid
    value.samples[2].timestamp = .nan
    assertFailure(value, .invalidTimestamp)
  }
  func testInvalidPhysicalReadings() {
    for angle in [Double.nan, .infinity, -1, 181] {
      var value = valid
      value.samples[0].angle = angle
      assertFailure(value, .invalidReading)
    }
  }
  func testRequestAndReturnPreserveEncoding() throws {
    var link = URLComponents(string: "duofold://verify")!
    link.queryItems = [URLQueryItem(name: "session", value: "ABC123abc456"),
      URLQueryItem(name: "callback", value: "https://example.com/demo?source=one%26two&result=old&session=old")]
    let request = try XCTUnwrap(VerificationRequest(url: link.url!))
    let result = URLComponents(url: request.successURL(), resolvingAgainstBaseURL: false)!
    XCTAssertEqual(result.queryItems?.filter { $0.name == "session" }.map(\.value), ["ABC123abc456"])
    XCTAssertEqual(result.queryItems?.first { $0.name == "result" }?.value, "success")
    XCTAssertEqual(result.queryItems?.first { $0.name == "source" }?.value, "one&two")
  }
  func testRejectMalformedRequests() {
    for string in ["duofold://verify", "duofold://wrong?session=ABC123abc456&callback=https://example.com",
      "duofold://verify?session=ABC123abc456&callback=http://example.com",
      "duofold://verify?session=ABC123abc456&session=ABC123abc456&callback=https://example.com",
      "duofold://verify?session=ABC123abc456&callback=https://user:pass@example.com"] {
      XCTAssertNil(VerificationRequest(url: URL(string: string)!))
    }
  }
}

private struct SeededRandom: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
    return state
  }
}
