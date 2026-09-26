import SwiftUI

@available(iOS 27.1, *)
struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL
  @ScaledMetric(relativeTo: .subheadline) private var markerWidth: CGFloat = 58
  @State private var session = FoldSession()
  @State private var showStepCheck = false
  @State private var checkTask: Task<Void, Never>?

  var body: some View {
    GeometryReader { geometry in
      // Keep the challenge on the display center even when a side bar insets the safe area.
      let centerCorrection = (geometry.safeAreaInsets.trailing - geometry.safeAreaInsets.leading) / 2
      ZStack {
        FoldProtractor(
          angle: session.capture.angle,
          target: session.visualTarget,
          matched: session.isVisuallyMatched
        )
        .padding(18)
        .frame(
          width: geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing,
          height: geometry.size.height
        )
        .offset(x: centerCorrection)
        .transaction { $0.animation = nil }

        information(
          holdRingSize: min(104, max(56, geometry.size.height * 0.17)),
          availableWidth: geometry.size.width,
          centerCorrection: centerCorrection
        )

        if showStepCheck && session.phase == .active {
          checkScreen(size: geometry.size, completed: false, centerCorrection: centerCorrection)
            .id(session.feedback.step)
        }

        if session.phase == .verified {
          checkScreen(size: geometry.size, completed: true, centerCorrection: centerCorrection)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(Color(uiColor: .systemBackground).ignoresSafeArea())
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
      showStepCheck = false
      checkTask = Task { @MainActor in
        do { try await Task.sleep(for: .seconds(FoldSession.snapFeedbackSeconds)) } catch { return }
        guard session.phase == .active else { return }
        showStepCheck = true
        do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
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

  private func information(holdRingSize: CGFloat, availableWidth: CGFloat, centerCorrection: CGFloat) -> some View {
    VStack(spacing: 14) {
      Text("Bend to the target angle")
        .font(.system(.title2, design: .rounded).weight(.semibold))
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(.isHeader)
        .offset(x: centerCorrection)

      if session.machine != nil {
        progressMarkers(availableWidth: availableWidth)
          .offset(x: centerCorrection)
      }

      Spacer(minLength: holdRingSize + 28)
        .overlay {
          Group {
            if session.phase == .active && session.machine?.step == 2 && session.snapAngle == nil {
              holdProgress(size: holdRingSize)
            } else if session.phase == .checking {
              ProgressView("Checking…")
            } else if session.phase == .retry {
              Button("Try a new challenge", systemImage: "arrow.clockwise") { session.retry() }
                .buttonStyle(.borderedProminent)
            } else if session.phase == .unavailable {
              Text("iPhone Duo hinge unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else if session.phase == .invalidLink {
              Text("Open verification from the website")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
          .offset(x: centerCorrection)
        }

      angleReadouts
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func progressMarkers(availableWidth: CGFloat) -> some View {
    HStack(spacing: 18) {
      ForEach(0..<3) { index in
        Group {
          if index < completedSteps {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else if let targets = session.machine?.challenge.targets {
            Text("\(Int(targets[index]))°")
              .foregroundStyle(index == completedSteps ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
        }
        .frame(width: min(markerWidth, max(32, (availableWidth - 84) / 3)))
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
      angleReadout(label: "TARGET", value: session.visualTarget)
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

  private func holdProgress(size: CGFloat) -> some View {
    VStack(spacing: 8) {
      Text(session.isInRange ? "HOLD" : (session.hasEnteredHold ? "RETURN TO TARGET" : "MATCH TARGET"))
        .font(.caption.weight(.semibold))
        .tracking(1.2)
      HoldCheckRing(progress: session.progress, size: size)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Final fold hold progress")
    .accessibilityValue("\(Int(session.progress * 100)) percent, \(session.isInRange ? "holding" : "paused")")
  }

  private func checkScreen(size: CGSize, completed: Bool, centerCorrection: CGFloat) -> some View {
    ZStack {
      VStack(spacing: 16) {
        CompletionCheckmark(size: min(size.width, size.height) * 0.62, startsFilled: completed)
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
      .offset(x: centerCorrection)
    }
    .frame(width: size.width, height: size.height)
    .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(completed ? "Human Verified" : "Fold matched")
  }
}
