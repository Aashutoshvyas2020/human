import SwiftUI

@Observable @MainActor
final class HingeCapture {
  private let clock = ContinuousClock()
  private let origin: ContinuousClock.Instant
  private(set) var angle: Double?
  private(set) var supported: Bool?
  init() { origin = clock.now }

  var now: TimeInterval {
    let parts = origin.duration(to: clock.now).components
    return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
  }

  @available(iOS 27.1, *)
  func receive(_ context: DeviceHingeContext) -> HingeSample? {
    supported = context.hinge != nil
    guard let hinge = context.hinge else { angle = nil; return nil }
    angle = hinge.angle.degrees
    return HingeSample(timestamp: now, angle: hinge.angle.degrees)
  }
}
