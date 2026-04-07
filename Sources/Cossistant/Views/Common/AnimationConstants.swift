import SwiftUI

/// Centralized animation and transition constants for the support SDK.
/// All animations respect `accessibilityReduceMotion` when used via the provided helpers.
enum CossistantAnimation {
  /// Standard spring used throughout the SDK.
  static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)

  /// Quick ease-out for subtle movements.
  static let quick = Animation.easeOut(duration: 0.15)

  /// Smooth ease-out for content transitions.
  static let smooth = Animation.easeOut(duration: 0.25)
}

// MARK: - Transitions

extension AnyTransition {
  /// Slide up with fade — ideal for new message insertion.
  static var slideUpFade: AnyTransition {
    .asymmetric(
      insertion: .move(edge: .bottom)
        .combined(with: .opacity)
        .animation(.easeOut(duration: 0.15)),
      removal: .opacity.animation(.easeOut(duration: 0.1))
    )
  }

  /// Scale from 0.85 with fade — ideal for events and indicators.
  static var fadeInScale: AnyTransition {
    .scale(scale: 0.85)
      .combined(with: .opacity)
      .animation(.easeOut(duration: 0.25))
  }

  /// Subtle insertion for list rows — fades in with a gentle vertical nudge.
  static var listRow: AnyTransition {
    .asymmetric(
      insertion: .opacity
        .combined(with: .offset(y: 10))
        .animation(.easeOut(duration: 0.3)),
      removal: .opacity.animation(.easeOut(duration: 0.15))
    )
  }

  /// Scale from 0.5 with fade — ideal for images loading in.
  static var scaleIn: AnyTransition {
    .scale(scale: 0.5)
      .combined(with: .opacity)
      .animation(.easeOut(duration: 0.2))
  }
}

// MARK: - Reduce Motion Helpers

extension View {
  /// Applies animation only when `accessibilityReduceMotion` is off.
  func cossistantAnimation<V: Equatable>(
    _ animation: Animation = CossistantAnimation.spring,
    value: V
  ) -> some View {
    modifier(ReduceMotionAnimationModifier(animation: animation, value: value))
  }
}

private struct ReduceMotionAnimationModifier<V: Equatable>: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let animation: Animation
  let value: V

  func body(content: Content) -> some View {
    content.animation(reduceMotion ? nil : animation, value: value)
  }
}

/// Performs a `withAnimation` block, respecting reduce motion at call-time.
@MainActor
func withCossistantAnimation(
  _ animation: Animation = CossistantAnimation.spring,
  _ body: () -> Void
) {
  // Check accessibility directly since we're outside a View context
  #if canImport(UIKit)
  if UIAccessibility.isReduceMotionEnabled {
    body()
    return
  }
  #elseif canImport(AppKit)
  if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
    body()
    return
  }
  #endif
  withAnimation(animation, body)
}
