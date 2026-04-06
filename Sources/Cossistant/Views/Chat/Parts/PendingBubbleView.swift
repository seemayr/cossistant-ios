import SwiftUI

/// A pending message bubble showing sending/failed state.
public struct PendingBubbleView: View {
  let message: PendingMessage
  let onRetry: (() -> Void)?
  let onDiscard: (() -> Void)?

  public init(
    message: PendingMessage,
    onRetry: (() -> Void)? = nil,
    onDiscard: (() -> Void)? = nil
  ) {
    self.message = message
    self.onRetry = onRetry
    self.onDiscard = onDiscard
  }

  public var body: some View {
    HStack {
      Spacer(minLength: 60)

      VStack(alignment: .trailing, spacing: 4) {
        Text(message.text)
          .font(.body)
          .foregroundStyle(.white.opacity(isFailed ? 0.7 : 0.9))
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(isFailed ? Color.red.opacity(0.7) : Color.accentColor.opacity(0.6))
          .clipShape(.rect(cornerRadius: 16))
          .animation(CossistantAnimation.quick, value: isFailed)

        if isFailed {
          HStack(spacing: 12) {
            Button(R.string(.retry_short)) { onRetry?() }
              .font(.caption)
              .buttonStyle(HapticButtonStyle(haptic: .retry))
            Button(R.string(.discard)) { onDiscard?() }
              .font(.caption)
              .foregroundStyle(.secondary)
              .buttonStyle(HapticButtonStyle())
          }
          .transition(.fadeInScale)
        } else {
          HStack(spacing: 4) {
            ProgressView()
              .scaleEffect(0.6)
            Text(R.string(.sending))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private var isFailed: Bool {
    if case .failed = message.status { return true }
    return false
  }
}
