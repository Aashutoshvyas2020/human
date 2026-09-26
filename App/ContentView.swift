import SwiftUI

@available(iOS 27.1, *)
struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var session = FoldSession()
  @State private var showStepCheck = false
  @State private var checkTask: Task<Void, Never>?

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()

        ArrangementView {
          information
        } secondary: {
          FoldProtractor(
            angle: session.capture.angle,
            target: session.visualTarget,
            matched: session.phase == .active && (session.snapAngle != nil || session.isInRange)
          )
          .animation(reduceMotion ? nil : .smooth(duration: 0.08), value: session.capture.angle)
          .padding(18)
        }
        .arrangementViewStyle(.overlay)

        if showStepCheck && session.phase == .active {
          checkScreen(size: geometry.size, completed: false)
        }

        if session.phase == .verified {
          checkScreen(size: geometry.size, completed: true)
        }
      }
    }
    .modifier(FoldFeedbackModifier(feedback: session.feedback))
    .onHingeChange { _, context in session.receive(context) }
    .onOpenURL { session.open($0) }
    .onChange(of: scenePhase, initial: true) { _, phase in session.sceneChanged(phase) }
    .onChange(of: session.returnURL) { _, url in
      guard let url else { return }
      openURL(url) { accepted in session.reportReturn(accepted, url: url) }
    }
    .onChange(of: session.feedback.step) { oldStep, newStep in
      guard newStep > oldStep, session.phase == .active else { return }
      checkTask?.cancel()
      showStepCheck = true
      checkTask = Task { @MainActor in
        do { try await Task.sleep(for: .milliseconds(320)) } catch { return }
        showStepCheck = false
      }
    }
    .onChange(of: session.phase) { _, phase in
      if phase != .active {
        checkTask?.cancel()
        showStepCheck = false
      }
    }
    .onChange(of: session.announcement) { _, announcement in
      guard !announcement.isEmpty else { return }
      AccessibilityNotification.Announcement(announcement).post()
    }
  }

  private var information: some View {
    VStack(spacing: 14) {
      Text("Bend to the target angle")
        .font(.system(.title2, design: .rounded).weight(.semibold))
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(.isHeader)

      if session.machine != nil {
        progressMarkers
      }

      Spacer(minLength: 80)

      if session.phase == .checking {
        ProgressView("Checking…")
      }

      if session.phase == .retry {
        Button("Try a new challenge", systemImage: "arrow.clockwise") { session.retry() }
          .buttonStyle(.borderedProminent)
      }

      if session.phase == .unavailable {
        Text("iPhone Duo hinge unavailable")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if session.phase == .invalidLink {
        Text("Open verification from the website")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if session.phase == .active && session.machine?.step == 2 {
        holdProgress
      }

      angleReadouts
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var progressMarkers: some View {
    HStack(spacing: 18) {
      ForEach(0..<3) { index in
        if index < completedSteps {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
        } else if let targets = session.machine?.challenge.targets {
          Text("\(Int(targets[index]))°")
            .foregroundStyle(index == completedSteps ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        }
      }
    }
    .font(.subheadline.weight(.semibold))
    .monospacedDigit()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Goal fold angles")
    .accessibilityValue("\(session.machine?.challenge.targets.map { "\(Int($0)) degrees" }.joined(separator: ", ") ?? ""), \(completedSteps) of 3 complete")
  }

  private var completedSteps: Int {
    session.phase == .verified ? 3 : min(session.machine?.step ?? 0, 3)
  }

  private var angleReadouts: some View {
    HStack(alignment: .firstTextBaseline, spacing: 20) {
      angleReadout(label: "LIVE", value: session.capture.angle)
      Spacer(minLength: 0)
      angleReadout(label: "TARGET", value: session.phase == .active ? session.target : nil)
    }
    .frame(maxWidth: 460)
  }

  private func angleReadout(label: String, value: Double?) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption2.weight(.bold))
        .tracking(1.3)
        .foregroundStyle(.secondary)
      Text(value.map { "\(Int($0.rounded()))°" } ?? "—°")
        .font(.system(.largeTitle, design: .rounded).weight(.bold))
        .monospacedDigit()
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label == "LIVE" ? "Live fold angle" : "Target fold angle")
    .accessibilityValue(value.map { "\(Int($0.rounded())) degrees" } ?? "Unavailable")
  }

  private var holdProgress: some View {
    VStack(spacing: 8) {
      Text(session.isInRange ? "HOLD" : "RETURN TO TARGET")
        .font(.caption.weight(.semibold))
        .tracking(1.2)
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.primary.opacity(0.12))
          Capsule().fill(Color.primary)
            .frame(width: geometry.size.width * max(0, min(1, session.progress)))
        }
      }
      .frame(height: 8)
    }
    .frame(maxWidth: 260)
    .padding(.bottom, 8)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Final fold hold progress")
    .accessibilityValue("\(Int(session.progress * 100)) percent")
  }

  private func checkScreen(size: CGSize, completed: Bool) -> some View {
    ZStack {
      Color(uiColor: .systemBackground).ignoresSafeArea()
      VStack(spacing: 16) {
        CompletionCheckmark(size: min(size.width, size.height) * 0.62)
        if completed {
          Text("Human Verified")
            .font(.system(.title, design: .rounded).weight(.semibold))
            .accessibilityAddTraits(.isHeader)
          if session.returnFailed {
            Button("Return to website") {
              session.prepareReturn()
              if let url = session.returnURL {
                openURL(url) { accepted in session.reportReturn(accepted, url: url) }
              }
            }
            .buttonStyle(.borderedProminent)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(completed ? "Human Verified" : "Fold matched")
  }
}
