import SwiftUI
import SFSafeSymbols

/// Minimal fullscreen image viewer. Tap the close button or swipe down to dismiss.
struct ImageViewerView: View {
  let url: URL
  let filename: String?

  @Environment(\.dismiss) private var dismiss
  @State private var dismissOffset: CGFloat = 0

  private var backgroundOpacity: Double {
    max(0.3, 1 - Double(dismissOffset) / 300)
  }

  var body: some View {
    ZStack {
      Color.black
        .opacity(backgroundOpacity)
        .ignoresSafeArea()
        .onTapGesture { dismiss() }

      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.horizontal, 4)
        case .failure:
          VStack(spacing: 12) {
            Image(systemSymbol: .photoFill)
              .font(.largeTitle)
              .foregroundStyle(.white.opacity(0.5))
            Text(R.string(.image_load_failed))
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.7))
          }
        default:
          ProgressView()
            .tint(.white)
            .scaleEffect(1.2)
        }
      }
      .offset(y: dismissOffset)
      .gesture(dismissDrag)

      VStack {
        HStack {
          Spacer()
          Button { dismiss() } label: {
            Image(systemSymbol: .xmark)
              .font(.system(size: 24, weight: .bold))
              .foregroundStyle(.white, .black.opacity(0.6))
              .padding(10)
              .background(Color.black.opacity(0.7))
              .clipShape(.circle)
          }
          .buttonStyle(HapticButtonStyle())
          .padding(20)
        }
        Spacer()
      }
    }
    #if os(iOS)
    .statusBarHidden()
    #endif
  }

  private var dismissDrag: some Gesture {
    DragGesture()
      .onChanged { value in
        dismissOffset = max(0, value.translation.height)
      }
      .onEnded { value in
        if dismissOffset > 120 || value.predictedEndTranslation.height > 300 {
          dismiss()
        } else {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dismissOffset = 0
          }
        }
      }
  }
}
