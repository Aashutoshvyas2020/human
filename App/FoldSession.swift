import SwiftUI
import OSLog

@Observable @MainActor
final class FoldSession {
  enum Phase { case idle, waiting, active, checking, verified, retry, unavailable, invalidLink }
  var capture = HingeCapture()
  private(set) var phase = Phase.idle
  private(set) var machine: ChallengeStateMachine?
  private(set) var trace: FoldTrace?
  private(set) var request: VerificationRequest?
  private(set) var feedback = FoldFeedback()
  private(set) var isActive = false
  private(set) var returnURL: URL?
  private(set) var returnFailed = false
  private(set) var progress = 0.0
  private(set) var message = ""
  private(set) var announcement = ""
  private(set) var snapAngle: Double?
  private var snapUntil = 0.0
  private var task: Task<Void, Never>?
  private var attempt = UUID()
  private var holdCueSent = false
  private var receivedWallTime = 0.0
  private var metrics: [String: Double] = [:]
  private let logger = Logger(subsystem: "DuoFold", category: "Verification")

  var target: Double? {
    guard let machine else { return nil }
    return machine.challenge.targets[min(machine.step, 2)]
  }
  var isInRange: Bool {
    guard let angle = capture.angle, let target else { return false }
    return abs(angle - target) <= FoldChallenge.tolerance
  }
  var visualTarget: Double? { phase == .active ? (snapAngle ?? target) : nil }

  func open(_ url: URL) {
    cancelWork()
    machine = nil
    trace = nil
    returnURL = nil
    returnFailed = false
    guard let request = VerificationRequest(url: url) else {
      self.request = nil
      phase = .invalidLink
      return
    }
    self.request = request
    receivedWallTime = Date().timeIntervalSince1970 * 1000
    phase = .waiting
    startIfReady()
  }

  func sceneChanged(_ scene: ScenePhase) {
    isActive = scene == .active
    if !isActive && (phase == .active || phase == .checking) {
      trace?.interruptedAt = capture.now
      fail("Verification paused when the app became inactive.")
    } else if isActive {
      startIfReady()
    }
  }

  @available(iOS 27.1, *)
  func receive(_ context: DeviceHingeContext) {
    guard let sample = capture.receive(context) else {
      if phase == .active { trace?.interruptedAt = capture.now }
      if phase != .verified {
        cancelWork()
        phase = .unavailable
      }
      return
    }
    guard sample.angle.isFinite, (0...180).contains(sample.angle) else {
      if phase == .active { fail("Hinge capture could not be read.") }
      return
    }
    if phase == .waiting || (phase == .unavailable && request != nil) {
      phase = .waiting
      startIfReady()
      // This event predates the new attempt. Never re-stamp a sensor event.
      return
    }
    if phase == .unavailable && request == nil { phase = .idle }
    guard phase == .active, isActive else { return }
    guard (trace?.samples.count ?? 0) < 30_000 else { fail("Start a fresh verification."); return }
    let previousStep = machine?.step ?? 0
    let previousTarget = target
    trace?.samples.append(sample)
    machine?.receive(sample)
    updateFeedback(previousStep: previousStep)
    if let nextStep = machine?.step, nextStep > previousStep, nextStep < 3 {
      snapAngle = previousTarget
      snapUntil = capture.now + 0.08
    }
    updateProgress()
    finishIfReady()
  }

  func retry() {
    cancelWork()
    phase = .waiting
    startIfReady()
  }
  func reportReturn(_ opened: Bool, url: URL) {
    guard returnURL == url else { return }
    returnFailed = !opened
    if opened { logger.info("Browser return requested successfully") }
  }

  private func startIfReady() {
    guard phase == .waiting, request != nil, isActive else { return }
    if capture.supported == false { phase = .unavailable; return }
    guard let angle = capture.angle, angle.isFinite else { return }
    var random = SystemRandomNumberGenerator()
    let challenge = FoldChallenge.generate(currentAngle: angle, using: &random)
    machine = ChallengeStateMachine(challenge: challenge)
    trace = FoldTrace(startedAt: capture.now)
    holdCueSent = false
    progress = 0
    phase = .active
    announcement = "Match the fold. Step 1 of 3."
    metrics = ["app_received_ms": receivedWallTime]
    let id = attempt
    task = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
        guard let self, self.attempt == id, self.phase == .active, self.isActive else { return }
        if self.capture.now >= self.snapUntil { self.snapAngle = nil }
        self.machine?.advanceTime(to: self.capture.now)
        self.updateProgress()
        self.finishIfReady()
      }
    }
  }

  private func updateFeedback(previousStep: Int) {
    if let step = machine?.step, step > previousStep, step < 3 {
      feedback.completeStep()
      announcement = "Step \(step + 1) of 3. \(step == 2 ? "Match, then hold." : "Match the fold.")"
    }
    if machine?.holdEnteredAt != nil && !holdCueSent {
      holdCueSent = true
      feedback.enterHold()
      announcement = "Hold this fold."
    }
  }
  private func updateProgress() {
    progress = (machine?.holdElapsed(at: capture.now) ?? 0) / FoldChallenge.holdDuration
  }

  private func finishIfReady() {
    guard phase == .active, isActive, machine?.isComplete == true,
      var trace, let challenge = machine?.challenge else { return }
    phase = .checking
    trace.completedAt = capture.now
    self.trace = trace
    task?.cancel()
    let id = attempt
    task = Task { [weak self] in
      await Task.yield()
      guard let self, !Task.isCancelled, self.attempt == id, self.isActive else { return }
      let began = self.capture.now
      let result = TrajectoryValidator().validate(trace, challenge: challenge)
      self.metrics["validation_ms"] = (self.capture.now - began) * 1000
      self.metrics["challenge_ms"] = ((trace.completedAt ?? began) - trace.startedAt) * 1000
      switch result {
      case .failure(let reason):
        self.logger.notice("Trace rejected: \(reason.rawValue, privacy: .public)")
        self.fail("The motion could not be confirmed. Give it another try.")
      case .success:
        let intervals = zip(trace.samples, trace.samples.dropFirst()).map { $1.timestamp - $0.timestamp }
        let speeds = zip(trace.samples, trace.samples.dropFirst()).map { abs($1.angle - $0.angle) / ($1.timestamp - $0.timestamp) }
        let count = trace.samples.count
        let maxGap = intervals.max() ?? 0
        let maxSpeed = speeds.max() ?? 0
        self.logger.info("Hinge capture: \(count) samples; maximum interval \(maxGap)s; maximum speed \(maxSpeed) degrees/s")
        self.phase = .verified
        self.feedback.completeStep()
        self.announcement = "Human Verified"
        do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
        guard !Task.isCancelled, self.attempt == id, self.isActive else { return }
        self.prepareReturn()
      }
    }
  }

  func prepareReturn() {
    guard phase == .verified, let request, isActive else { return }
    metrics["return_sent_ms"] = Date().timeIntervalSince1970 * 1000
    returnURL = request.successURL(metrics: metrics)
  }
  private func fail(_ explanation: String) {
    cancelWork()
    message = explanation
    phase = .retry
    announcement = "Try a new challenge"
  }
  private func cancelWork() {
    task?.cancel()
    task = nil
    attempt = UUID()
    snapAngle = nil
  }
}
