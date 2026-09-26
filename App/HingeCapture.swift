import SwiftUI
import OSLog

@Observable @MainActor
final class HingeCapture {
  private let clock = ContinuousClock()
  private let logger = Logger(subsystem: "DuoFold", category: "HingeCapture")
  private let origin: ContinuousClock.Instant
  private(set) var angle: Double?
  private(set) var supported: Bool?
  private var reportedFirstReading = false
  init() { origin = clock.now }

  var now: TimeInterval {
    let parts = origin.duration(to: clock.now).components
    return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
  }

  @available(iOS 27.1, *)
  func receive(_ context: DeviceHingeContext) -> HingeSample? {
    let hasHinge = context.hinge != nil
    if supported != hasHinge {
      logger.info("onHingeChange delivered hinge available: \(hasHinge)")
    }
    supported = hasHinge
    guard let hinge = context.hinge else { angle = nil; return nil }
    if !reportedFirstReading {
      logger.info("First raw hinge angle: \(hinge.angle.degrees) degrees")
      reportedFirstReading = true
    }
    angle = hinge.angle.degrees
    return HingeSample(timestamp: now, angle: hinge.angle.degrees)
  }
}
