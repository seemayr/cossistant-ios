import SwiftUI
import SFSafeSymbols

/// Image attachment with smooth placeholder-to-loaded transition.
struct ImagePartView: View {
  let image: ImagePart
  @State private var isLoaded = false

  var body: some View {
    AsyncImage(url: URL(string: image.url)) { phase in
      switch phase {
      case .empty:
        placeholder
      case .success(let img):
        img
          .resizable()
          .aspectRatio(contentMode: .fit)
          .scaleEffect(isLoaded ? 1 : 0.92)
          .opacity(isLoaded ? 1 : 0)
          .onAppear {
            withCossistantAnimation(.easeOut(duration: 0.25)) {
              isLoaded = true
            }
          }
      case .failure:
        failurePlaceholder
      @unknown default:
        placeholder
      }
    }
    .frame(maxWidth: 220, maxHeight: 180)
    .clipShape(.rect(cornerRadius: 12))
    .accessibilityLabel(image.filename ?? R.string(.image_accessibility))
  }

  private var placeholder: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(.secondary.opacity(0.08))
      .frame(maxWidth: 220, maxHeight: 180)
      .frame(minHeight: 80)
      .overlay {
        ProgressView()
          .tint(.secondary)
      }
  }

  private var failurePlaceholder: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(.secondary.opacity(0.08))
      .frame(width: 80, height: 60)
      .overlay {
        Image(systemSymbol: .photoFill)
          .foregroundStyle(.tertiary)
      }
  }
}
