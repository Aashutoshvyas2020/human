import SwiftUI

struct CompletionCheckmark: View {
  var size: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var ringProgress: CGFloat = 0
  @State private var checkVisible = false

  var body: some View {
    ZStack {
      Circle()
        .trim(from: 0, to: ringProgress)
        .stroke(.green, style: StrokeStyle(lineWidth: max(8, size * 0.038), lineCap: .round))
        .rotationEffect(.degrees(-90))

      Image(systemName: "checkmark")
        .font(.system(size: size * 0.48, weight: .medium))
        .foregroundStyle(.green)
        .scaleEffect(checkVisible ? 1 : 0.65)
        .opacity(checkVisible ? 1 : 0)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
    .task {
      if reduceMotion {
        ringProgress = 1
        checkVisible = true
        return
      }
      withAnimation(.smooth(duration: 0.20)) { ringProgress = 1 }
      do { try await Task.sleep(for: .milliseconds(115)) } catch { return }
      withAnimation(.bouncy(duration: 0.20)) { checkVisible = true }
    }
  }
}
