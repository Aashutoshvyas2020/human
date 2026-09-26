import SwiftUI

@available(iOS 27.1, *)
struct ContentView: View {
  @State private var session = FoldSession()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL

  var body: some View {
    NavigationStack {
      ArrangementView {
        status.padding(28)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      } secondary: {
        FoldSilhouette(angle: session.capture.angle ?? 110, target: session.visualTarget,
          matched: session.phase == .active && (session.snapAngle != nil || session.isInRange))
          .padding(32).padding(.bottom, 130)
      }
      .arrangementViewStyle(.overlay)
      .background(Color(.systemBackground))
      .navigationTitle("Duo Fold")
      .navigationBarTitleDisplayMode(.inline)
    }
    .modifier(FoldFeedbackModifier(feedback: session.feedback))
    .onHingeChange { _, context in session.receive(context) }
    .onOpenURL { session.open($0) }
    .onChange(of: scenePhase, initial: true) { _, phase in session.sceneChanged(phase) }
    .onChange(of: session.returnURL) { _, url in
      guard let url else { return }
      openURL(url) { accepted in session.reportReturn(accepted, url: url) }
    }
    .onChange(of: session.announcement) { _, announcement in
      guard !announcement.isEmpty else { return }
      AccessibilityNotification.Announcement(announcement).post()
    }
  }

  private var status: some View {
    ScrollView {
      VStack(spacing: 18) {
        Text(title).font(.largeTitle.weight(.semibold))
          .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
        switch session.phase {
        case .active:
          Text(session.machine?.step == 2 ? "Match, then hold" : "Follow the dashed outline")
            .font(.body).foregroundStyle(.secondary)
          HStack(spacing: 12) {
            ForEach(0..<3) { index in
              Circle().fill(index < (session.machine?.step ?? 0) ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                .frame(width: 8, height: 8)
            }
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Step \(min(3, (session.machine?.step ?? 0) + 1)) of 3")
          if session.machine?.step == 2 {
            ProgressView(value: session.progress).frame(maxWidth: 160)
              .accessibilityLabel("Hold progress")
              .accessibilityValue("\(Int(session.progress * 100)) percent")
          }
        case .checking:
          ProgressView().accessibilityLabel("Checking fold motion")
        case .verified:
          Image(systemName: "checkmark").font(.largeTitle).foregroundStyle(.tint).accessibilityHidden(true)
          Button("Return to website") { session.prepareReturn() }.buttonStyle(.bordered)
          if session.returnFailed { Text("Could not open the website. Try again.").font(.footnote) }
        case .retry:
          Text(session.message).foregroundStyle(.secondary)
          Button("Try a new challenge", systemImage: "arrow.clockwise") { session.retry() }
            .buttonStyle(.borderedProminent)
        case .waiting:
          Text("Open your Duo to begin.").foregroundStyle(.secondary)
        case .unavailable:
          Text("Verification requires an iPhone Duo with hinge input.").foregroundStyle(.secondary)
        case .invalidLink:
          Text("Return to the website and tap Verify again.").foregroundStyle(.secondary)
        case .idle:
          Text("A small fold. A human touch.").font(.title3).foregroundStyle(.secondary)
          Text("Start on the website. Tap Verify to match three folds and return instantly.")
            .font(.body).foregroundStyle(.secondary)
        }
      }
      .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(24)
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(maxWidth: 440, maxHeight: session.phase == .active ? 250 : 330)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
  }

  private var title: String {
    switch session.phase {
    case .idle: "The fold is the proof."
    case .waiting, .active: "Match the fold"
    case .checking: "Checking…"
    case .verified: "Human Verified"
    case .retry: "Try a new challenge"
    case .unavailable: "Duo required"
    case .invalidLink: "Invalid verification link"
    }
  }
}
