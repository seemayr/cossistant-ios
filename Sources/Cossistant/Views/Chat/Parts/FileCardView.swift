import SwiftUI
import SFSafeSymbols

/// Download-style card for file attachments.
struct FileCardView: View {
  let file: FilePart

  var body: some View {
    let content = HStack(spacing: 10) {
      fileIcon
        .font(.title3)
        .foregroundStyle(.tint)
        .frame(width: 32, height: 32)

      VStack(alignment: .leading, spacing: 2) {
        Text(file.filename ?? R.string(.file_default_name))
          .font(.subheadline)
          .lineLimit(1)
          .truncationMode(.middle)

        if let size = file.size {
          Text(formatFileSize(size))
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))

    if let url = URL(string: file.url) {
      Link(destination: url) { content }
    } else {
      content
    }
  }

  // MARK: - File Icon

  private var fileIcon: some View {
    Image(systemSymbol: iconForMediaType)
  }

  private var iconForMediaType: SFSymbol {
    let type = file.mediaType.lowercased()
    if type.contains("pdf") { return .docFill }
    if type.hasPrefix("image") { return .photoFill }
    if type.hasPrefix("video") { return .filmFill }
    if type.hasPrefix("audio") { return .waveformCircleFill }
    if type.contains("zip") || type.contains("compressed") { return .archiveboxFill }
    return .paperclipCircleFill
  }
}

// MARK: - File Size Formatting

private func formatFileSize(_ bytes: Int) -> String {
  let units = ["B", "KB", "MB", "GB"]
  var size = Double(bytes)
  var unitIndex = 0
  while size >= 1024 && unitIndex < units.count - 1 {
    size /= 1024
    unitIndex += 1
  }
  if unitIndex == 0 { return "\(bytes) B" }
  return String(format: "%.1f %@", size, units[unitIndex])
}
