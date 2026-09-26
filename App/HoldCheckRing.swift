import SwiftUI

struct HoldCheckRing: View {
  var progress: Double
  var size: CGFloat

  private var clampedProgress: CGFloat { CGFloat(max(0, min(1, progress))) }

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.primary.opacity(0.14), lineWidth: max(6, size * 0.055))

      Circle()
        .trim(from: 0, to: clampedProgress)
        .stroke(.green, style: StrokeStyle(lineWidth: max(6, size * 0.055), lineCap: .round))
        .rotationEffect(.degrees(-90))

      Image(systemName: "checkmark")
        .font(.system(size: size * 0.43, weight: .medium))
        .foregroundStyle(.primary.opacity(0.24))
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}
