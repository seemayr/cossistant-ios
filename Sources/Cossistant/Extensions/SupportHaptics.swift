#if canImport(UIKit)
import UIKit

/// Haptic feedback patterns for support interactions.
public enum SupportHaptics {
  /// Available haptic patterns for support events.
  public enum Pattern {
    case messageSent
    case messageReceived
    case conversationOpened
    case conversationCreated
    case error
    case typing
    case buttonTap
    case retry

    var events: [(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat, delay: TimeInterval)] {
      switch self {
      case .messageSent:
        return [(.light, 0.6, 0)]
      case .messageReceived:
        return [(.soft, 0.4, 0)]
      case .conversationOpened:
        return [(.light, 0.4, 0)]
      case .conversationCreated:
        return [
          (.light, 0.5, 0),
          (.light, 0.7, 0.08),
        ]
      case .error:
        return [
          (.heavy, 0.8, 0),
          (.heavy, 0.4, 0.15),
        ]
      case .typing:
        return [(.soft, 0.2, 0)]
      case .buttonTap:
        return [(.soft, 0.3, 0)]
      case .retry:
        return [(.medium, 0.5, 0)]
      }
    }
  }

  /// Whether haptics are enabled. Defaults to true.
  public nonisolated(unsafe) static var isEnabled = true

  @MainActor private static var generators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]

  @MainActor
  private static func generator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
    if let existing = generators[style] { return existing }
    let gen = UIImpactFeedbackGenerator(style: style)
    generators[style] = gen
    return gen
  }

  /// Plays a haptic pattern.
  @MainActor
  public static func play(_ pattern: Pattern) {
    guard isEnabled else { return }
    Task { @MainActor in
      for event in pattern.events {
        if event.delay > 0 {
          try? await Task.sleep(for: .seconds(event.delay))
        }
        let gen = generator(for: event.style)
        gen.prepare()
        gen.impactOccurred(intensity: event.intensity)
      }
    }
  }
}
#else
/// No-op haptics on macOS.
public enum SupportHaptics {
  public enum Pattern {
    case messageSent, messageReceived, conversationOpened, conversationCreated, error, typing, buttonTap, retry
  }
  public nonisolated(unsafe) static var isEnabled = true
  public static func play(_ pattern: Pattern) {}
}
#endif
