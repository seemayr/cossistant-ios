import SwiftUI

/// Decodes image `Data` off the main thread and displays a thumbnail.
///
/// Encapsulated as a separate struct to create a re-evaluation boundary —
/// the decoded image in `@State` survives parent re-renders, and decoding
/// never runs inside a parent's `@ViewBuilder` body.
struct DataImageView: View {
  let data: Data
  let size: CGSize

  @State private var image: Image?

  var body: some View {
    Group {
      if let image {
        image
          .resizable()
          .scaledToFill()
      } else {
        Color.clear
      }
    }
    .frame(width: size.width, height: size.height)
    .clipShape(.rect(cornerRadius: 8))
    .task(id: data) {
      image = await Self.decode(from: data, size: size)
    }
  }

  private static func decode(from data: Data, size: CGSize) async -> Image? {
    #if canImport(UIKit)
    guard let uiImage = UIImage(data: data) else { return nil }
    let scale = await UITraitCollection.current.displayScale
    let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
    let thumb = await uiImage.byPreparingThumbnail(ofSize: pixelSize)
    return Image(uiImage: thumb ?? uiImage)
    #elseif canImport(AppKit)
    guard let nsImage = NSImage(data: data) else { return nil }
    return Image(nsImage: nsImage)
    #endif
  }
}
