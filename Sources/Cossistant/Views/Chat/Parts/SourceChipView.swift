import SwiftUI
import SFSafeSymbols

/// Tappable pill chip for a source URL reference.
struct SourceUrlChipView: View {
  let source: SourceUrlPart

  var body: some View {
    if let url = URL(string: source.url) {
      Link(destination: url) {
        chipLabel(
          icon: .link,
          title: source.title ?? truncatedURL
        )
      }
    } else {
      chipLabel(
        icon: .link,
        title: source.title ?? source.url
      )
    }
  }

  private var truncatedURL: String {
    let cleaned = source.url
      .replacingOccurrences(of: "https://", with: "")
      .replacingOccurrences(of: "http://", with: "")
    if cleaned.count > 40 {
      return String(cleaned.prefix(37)) + "..."
    }
    return cleaned
  }
}

/// Non-tappable pill chip for a source document reference.
struct SourceDocumentChipView: View {
  let source: SourceDocumentPart

  var body: some View {
    chipLabel(
      icon: .docFill,
      title: source.title
    )
  }
}

// MARK: - Shared Chip Label

private func chipLabel(icon: SFSymbol, title: String) -> some View {
  HStack(spacing: 4) {
    Image(systemSymbol: icon)
      .font(.caption2)
    Text(title)
      .font(.caption)
      .lineLimit(1)
  }
  .foregroundStyle(.tint)
  .padding(.horizontal, 10)
  .padding(.vertical, 6)
  .background(.tint.opacity(0.1), in: .capsule)
}
