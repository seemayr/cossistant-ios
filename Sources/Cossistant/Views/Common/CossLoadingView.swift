import SwiftUI

/// Playful loading indicator — the coss face bounces in and gently bobs with a message label below.
struct CossLoadingView: View {
  let message: String

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false
  @State private var bouncing = false

  init(_ message: String = "Loading...") {
    self.message = message
  }

  var body: some View {
    VStack(spacing: 16) {
      cossImage
      Text(message)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
    }
    .task {
      appeared = true
      try? await Task.sleep(for: .milliseconds(400))
      bouncing = true
    }
  }

  private var cossImage: some View {
    Image("coss", bundle: .module)
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .frame(width: 40, height: 40)
      .foregroundStyle(.secondary)
      .opacity(appeared ? 1 : 0)
      .scaleEffect(appeared ? 1 : 0.3)
      .offset(y: bouncing ? -8 : 8)
      .rotationEffect(.degrees(bouncing ? 3 : -3))
      .scaleEffect(bouncing ? 1.08 : 0.95)
      .animation(
        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6),
        value: appeared
      )
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 0.8)
          .repeatForever(autoreverses: true),
        value: bouncing
      )
  }
}

/// Full-page loading overlay with the playful coss bouncing indicator.
struct CossLoadingOverlayView: View {
  let message: String

  init(_ message: String = "Connecting...") {
    self.message = message
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      CossLoadingView(message)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
