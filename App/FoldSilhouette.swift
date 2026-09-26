import SwiftUI

struct FoldSilhouette: View {
  var angle: Double
  var target: Double?
  var matched: Bool

  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let scale = min(size.width / 2.7, size.height / 2.1)
      if let target {
        let ghost = silhouette(angle: target, center: center, scale: scale)
        context.fill(ghost, with: .color(.primary.opacity(0.035)))
        context.stroke(ghost, with: .color(.primary.opacity(0.35)), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
      }
      let displayAngle = matched ? (target ?? angle) : angle
      let live = silhouette(angle: displayAngle, center: center, scale: scale)
      let proximity = target.map { max(0, 1 - abs($0 - angle) / 40) } ?? 0
      context.fill(live, with: .color(.accentColor.opacity(0.08 + proximity * 0.10)))
      context.stroke(live, with: .color(.accentColor), style: StrokeStyle(lineWidth: matched ? 3.5 : 2.5, lineCap: .round, lineJoin: .round))
      var hinge = Path()
      hinge.move(to: CGPoint(x: center.x, y: center.y - scale * 0.62))
      hinge.addLine(to: CGPoint(x: center.x, y: center.y + scale * 0.62))
      context.stroke(hinge, with: .color(.accentColor.opacity(0.5)), lineWidth: 1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityLabel("Live fold and target")
    .accessibilityValue(target.map { matched ? "Matched" : angle < $0 ? "Open a little more" : "Close a little more" } ?? "Open Duo Fold from the website")
    .accessibilityHint("Match the solid outline to the dashed outline by folding your iPhone.")
  }

  private func silhouette(angle: Double, center: CGPoint, scale: Double) -> Path {
    let half = max(0, min(180, angle)) * .pi / 360
    let width = sin(half) * scale
    let depth = cos(half) * scale * 0.55
    let height = scale * 0.62
    var path = Path()
    path.move(to: CGPoint(x: center.x, y: center.y - height))
    path.addLine(to: CGPoint(x: center.x - width, y: center.y - height + depth))
    path.addLine(to: CGPoint(x: center.x - width, y: center.y + height + depth))
    path.addLine(to: CGPoint(x: center.x, y: center.y + height))
    path.addLine(to: CGPoint(x: center.x + width, y: center.y + height + depth))
    path.addLine(to: CGPoint(x: center.x + width, y: center.y - height + depth))
    path.closeSubpath()
    return path
  }
}
