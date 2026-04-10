import SwiftUI
import SFSafeSymbols

struct SupportPreparationBanner: View {
  let issue: SupportPreparationIssue
  let isRetrying: Bool
  let onRetry: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemSymbol: .exclamationmarkTriangleFill)
        .foregroundStyle(.orange)
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: 4) {
        Text(issue.title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)

        Text(issue.message)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      Button(action: onRetry) {
        if isRetrying {
          ProgressView()
            .controlSize(.small)
        } else {
          Text("Retry")
            .font(.footnote.weight(.semibold))
        }
      }
      .buttonStyle(.borderless)
      .disabled(isRetrying)
    }
    .padding(12)
    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(.orange.opacity(0.28), lineWidth: 1)
    )
  }
}
