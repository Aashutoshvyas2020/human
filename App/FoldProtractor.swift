import SwiftUI

struct FoldProtractor: View {
  var angle: Double?
  var target: Double?
  var matched: Bool

  var body: some View {
    Canvas { context, size in
      let radius = min(max(20, size.width / 2 - 28), max(20, size.height * 0.58))
      let center = CGPoint(x: size.width / 2, y: size.height * 0.78)
      let outer = ring(from: 0, to: 180, center: center, radius: radius)
      context.stroke(outer, with: .color(.primary.opacity(0.13)),
        style: StrokeStyle(lineWidth: 14, lineCap: .round))

      for degree in stride(from: 0.0, through: 180.0, by: 30.0) {
        var tick = Path()
        tick.move(to: point(for: degree, center: center, radius: radius - 19))
        tick.addLine(to: point(for: degree, center: center, radius: radius - 29))
        context.stroke(tick, with: .color(.primary.opacity(0.35)), lineWidth: 2)
      }

      if let target {
        let zone = ring(from: max(0, target - FoldChallenge.tolerance),
          to: min(180, target + FoldChallenge.tolerance), center: center, radius: radius)
        context.stroke(zone, with: .color(.primary.opacity(0.4)),
          style: StrokeStyle(lineWidth: 18, lineCap: .round))

        let marker = point(for: target, center: center, radius: radius)
        var targetLine = Path()
        targetLine.move(to: point(for: target, center: center, radius: radius - 28))
        targetLine.addLine(to: point(for: target, center: center, radius: radius + 11))
        context.stroke(targetLine, with: .color(.primary),
          style: StrokeStyle(lineWidth: 3, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: marker.x - 5, y: marker.y - 5,
          width: 10, height: 10)), with: .color(.primary))
      }

      if let angle {
        let displayAngle = matched ? (target ?? angle) : angle
        let current = ring(from: 0, to: max(0, min(180, displayAngle)),
          center: center, radius: radius)
        context.stroke(current, with: .color(.primary),
          style: StrokeStyle(lineWidth: matched ? 16 : 12, lineCap: .round))

        let tip = point(for: displayAngle, center: center, radius: radius)
        context.fill(Path(ellipseIn: CGRect(x: tip.x - 9, y: tip.y - 9,
          width: 18, height: 18)), with: .color(.primary))
        context.fill(Path(ellipseIn: CGRect(x: tip.x - 4, y: tip.y - 4,
          width: 8, height: 8)), with: .color(Color(uiColor: .systemBackground)))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Live fold angle and target")
    .accessibilityValue(accessibilityValue)
    .accessibilityHint("Bend until the live arc reaches the target marker.")
  }

  private var accessibilityValue: String {
    guard let angle else { return "Waiting for hinge reading" }
    guard let target else { return "Current fold \(Int(angle.rounded())) degrees" }
    if matched { return "Matched at \(Int(target.rounded())) degrees" }
    return "Live \(Int(angle.rounded())) degrees; target \(Int(target.rounded())) degrees"
  }

  private func ring(from start: Double, to end: Double, center: CGPoint, radius: CGFloat) -> Path {
    var path = Path()
    let lower = min(start, end)
    let upper = max(start, end)
    path.move(to: point(for: lower, center: center, radius: radius))
    for degree in stride(from: lower + 1, through: upper, by: 1.0) {
      path.addLine(to: point(for: degree, center: center, radius: radius))
    }
    path.addLine(to: point(for: upper, center: center, radius: radius))
    return path
  }

  private func point(for degrees: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
    let radians = .pi - max(0, min(180, degrees)) * .pi / 180
    return CGPoint(x: center.x + cos(radians) * radius,
      y: center.y - sin(radians) * radius)
  }
}
