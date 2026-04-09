import SwiftUI

/// A pending message bubble showing sending/failed state.
struct PendingBubbleView: View {
  let message: PendingMessage
  let onRetry: (() -> Void)?
  let onDiscard: (() -> Void)?

  @Environment(\.cossistantDesign) private var design

  init(
    message: PendingMessage,
    onRetry: (() -> Void)? = nil,
    onDiscard: (() -> Void)? = nil
  ) {
    self.message = message
    self.onRetry = onRetry
    self.onDiscard = onDiscard
  }

  var body: some View {
    HStack {
      Spacer(minLength: 60)

      VStack(alignment: .trailing, spacing: 4) {
        if !message.text.isEmpty {
          if message.text.isScaledEmoji {
            Text(message.text)
              .font(.system(size: message.text.emojiFontSize))
              .fixedSize(horizontal: false, vertical: true)
              .opacity(isFailed ? 0.5 : 0.8)
              .animation(CossistantAnimation.quick, value: isFailed)
          } else {
            Text(message.text)
              .font(.body)
              .foregroundStyle(.white.opacity(isFailed ? 0.7 : 0.9))
              .padding(.horizontal, 14)
              .padding(.vertical, 10)
              .background(isFailed ? Color.red.opacity(0.7) : design.accentColor.opacity(0.6))
              .clipShape(.rect(cornerRadius: 16))
              .animation(CossistantAnimation.quick, value: isFailed)
          }
        }

        if !message.attachments.isEmpty {
          pendingAttachments
        }

        if isFailed {
          HStack(spacing: 12) {
            Button(R.string(.retry_short)) { onRetry?() }
              .font(.subheadline)
              .buttonStyle(HapticButtonStyle(haptic: .retry))
            
//            Button(R.string(.discard)) { onDiscard?() }
//              .font(.subheadline)
//              .foregroundStyle(.secondary)
//              .buttonStyle(HapticButtonStyle())
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

  @ViewBuilder
  private var pendingAttachments: some View {
    HStack(spacing: 4) {
      ForEach(message.attachments) { attachment in
        if attachment.isImage {
          DataImageView(data: attachment.data, size: CGSize(width: 48, height: 48))
            .opacity(isFailed ? 0.6 : 0.8)
        } else {
          VStack(spacing: 2) {
            Image(systemSymbol: .docFill)
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(attachment.fileName)
              .font(.caption2)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          .frame(width: 48, height: 48)
          .background(.secondary.opacity(0.08))
          .clipShape(.rect(cornerRadius: 8))
          .opacity(isFailed ? 0.6 : 0.8)
        }
      }
    }
  }
}
