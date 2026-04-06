import SwiftUI
import SFSafeSymbols

/// Collapsible "thinking" disclosure for AI reasoning parts.
struct ReasoningView: View {
  let reasoning: ReasoningPart
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      if isExpanded {
        expandedContent
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.secondary.opacity(0.05), in: .rect(cornerRadius: 12))
  }

  // MARK: - Header

  private var header: some View {
    Button {
      withCossistantAnimation { isExpanded.toggle() }
    } label: {
      HStack(spacing: 6) {
        Image(systemSymbol: .brain)
          .font(.caption)
          .foregroundStyle(.tint)
        Text(isDone ? R.string(.reasoning_done) : R.string(.reasoning_active))
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Image(systemSymbol: .chevronRight)
          .font(.caption2)
          .foregroundStyle(.tertiary)
          .rotationEffect(.degrees(isExpanded ? 90 : 0))
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Expanded

  private var expandedContent: some View {
    Text(reasoning.text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.top, 8)
      .padding(.leading, 8)
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(.tint.opacity(0.3))
          .frame(width: 2)
          .padding(.top, 8)
      }
  }

  private var isDone: Bool {
    reasoning.state == "done"
  }
}
