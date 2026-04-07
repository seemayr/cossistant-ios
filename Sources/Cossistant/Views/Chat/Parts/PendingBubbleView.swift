import SwiftUI

/// A pending message bubble showing sending/failed state.
struct PendingBubbleView: View {
  let message: PendingMessage
  let onRetry: (() -> Void)?
  let onDiscard: (() -> Void)?

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
          Text(message.text)
            .font(.body)
            .foregroundStyle(.white.opacity(isFailed ? 0.7 : 0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isFailed ? Color.red.opacity(0.7) : Color.accentColor.opacity(0.6))
            .clipShape(.rect(cornerRadius: 16))
            .animation(CossistantAnimation.quick, value: isFailed)
        }

        if !message.attachments.isEmpty {
          pendingAttachments
        }

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

  @ViewBuilder
  private var pendingAttachments: some View {
    HStack(spacing: 4) {
      ForEach(message.attachments) { attachment in
        if attachment.isImage {
          #if canImport(UIKit)
          if let uiImage = UIImage(data: attachment.data) {
            Image(uiImage: uiImage)
              .resizable()
              .scaledToFill()
              .frame(width: 48, height: 48)
              .clipShape(.rect(cornerRadius: 8))
              .opacity(isFailed ? 0.6 : 0.8)
          }
          #elseif canImport(AppKit)
          if let nsImage = NSImage(data: attachment.data) {
            Image(nsImage: nsImage)
              .resizable()
              .scaledToFill()
              .frame(width: 48, height: 48)
              .clipShape(.rect(cornerRadius: 8))
              .opacity(isFailed ? 0.6 : 0.8)
          }
          #endif
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
