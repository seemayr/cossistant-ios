import SwiftUI

/// Custom loading indicator with animated dots — gives the support SDK its own identity.
struct SupportLoadingView: View {
  let message: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var activeDot = 0

  init(_ message: String = "Loading...") {
    self.message = message
  }

  var body: some View {
    VStack(spacing: 16) {
      dotsIndicator
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .task(id: reduceMotion) {
      guard !reduceMotion else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeInOut(duration: 0.25)) {
          activeDot = (activeDot + 1) % 3
        }
      }
    }
  }

  private var dotsIndicator: some View {
    HStack(spacing: 8) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(.tint.opacity(index == activeDot ? 1 : 0.25))
          .frame(width: 10, height: 10)
          .scaleEffect(index == activeDot ? 1.3 : 1)
      }
    }
  }
}

/// Full-page loading overlay with the custom indicator.
struct SupportLoadingOverlayView: View {
  let message: String

  init(_ message: String = "Connecting...") {
    self.message = message
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      SupportLoadingView(message)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
