import SwiftUI

/// Reusable animated dots indicator with reduce-motion support.
/// Replaces three separate dot implementations (typing, AI progress, tool).
struct AnimatedDotsView: View {
  enum Style {
    /// Dots bounce vertically — typing indicators.
    case bounce
    /// Dots scale and pulse — AI processing.
    case pulse
    /// Dots fade in/out — inline tool activity.
    case subtle
  }

  let style: Style
  var color: Color = .accentColor
  var dotSize: CGFloat = 6
  var spacing: CGFloat = 4

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isAnimating = false

  var body: some View {
    HStack(spacing: spacing) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(color)
          .frame(width: dotSize, height: dotSize)
          .modifier(DotAnimationModifier(
            style: style,
            index: index,
            isAnimating: isAnimating
          ))
          .animation(
            reduceMotion ? nil : animation(for: index),
            value: isAnimating
          )
      }
    }
    .task(id: reduceMotion) {
      guard !reduceMotion else {
        isAnimating = false
        return
      }
      isAnimating = true
    }
  }

  private func animation(for index: Int) -> Animation {
    let duration: Double
    let delay = Double(index) * 0.15

    switch style {
    case .bounce: duration = 0.4
    case .pulse: duration = 0.6
    case .subtle: duration = 0.5
    }

    return .easeInOut(duration: duration)
      .repeatForever(autoreverses: true)
      .delay(delay)
  }
}

// MARK: - Per-Style Modifier

private struct DotAnimationModifier: ViewModifier {
  let style: AnimatedDotsView.Style
  let index: Int
  let isAnimating: Bool

  func body(content: Content) -> some View {
    switch style {
    case .bounce:
      content
        .offset(y: isAnimating ? -4 : 0)
    case .pulse:
      content
        .scaleEffect(isAnimating ? 1.2 : 0.6)
        .opacity(isAnimating ? 1 : 0.3)
    case .subtle:
      content
        .opacity(isAnimating ? 1 : 0.3)
    }
  }
}
