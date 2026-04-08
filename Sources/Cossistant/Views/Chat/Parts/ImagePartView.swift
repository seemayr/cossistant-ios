import SwiftUI
import ImageIO
import SFSafeSymbols

extension URL: @retroactive Identifiable {
  public var id: String { absoluteString }
}

/// Image attachment with smooth placeholder-to-loaded transition.
/// Tap to view fullscreen.
struct ImagePartView: View {
  let image: ImagePart
  @State private var loaded: CachedImage?
  @State private var failed = false
  @State private var appeared = false
  @State private var viewerURL: URL?
  @State private var loadAttempt = 0

  private static let maxSize = CGSize(width: 220, height: 180)
  private static let defaultRatio: CGFloat = 4.0 / 3.0

  /// Use API metadata when available, fall back to decoded size, then default 4:3.
  private var imageRatio: CGFloat {
    if let w = image.width, let h = image.height, w > 0, h > 0 {
      return CGFloat(w) / CGFloat(h)
    }
    if let s = loaded?.originalSize, s.width > 0, s.height > 0 {
      return s.width / s.height
    }
    return Self.defaultRatio
  }

  /// Compute the exact display size that fits the image ratio within maxSize.
  private var displaySize: CGSize {
    let ratio = imageRatio
    guard ratio.isFinite, ratio > 0 else { return Self.maxSize }
    let maxW = Self.maxSize.width
    let maxH = Self.maxSize.height
    let heightByWidth = maxW / ratio
    if heightByWidth <= maxH {
      return CGSize(width: maxW, height: heightByWidth)
    }
    return CGSize(width: maxH * ratio, height: maxH)
  }

  var body: some View {
    content
      .frame(width: displaySize.width, height: displaySize.height)
      .clipShape(.rect(cornerRadius: 12))
      .contentShape(.rect(cornerRadius: 12))
      .accessibilityLabel(image.filename ?? R.string(.image_accessibility))
      .task(id: loadAttempt) { await load() }
    #if os(iOS)
    .fullScreenCover(item: $viewerURL) { url in
      ImageViewerView(url: url, filename: image.filename)
    }
    #else
    .sheet(item: $viewerURL) { url in
      ImageViewerView(url: url, filename: image.filename)
    }
    #endif
  }

  @ViewBuilder
  private var content: some View {
    if let loaded {
      Button { viewerURL = URL(string: image.url) } label: {
        loaded.swiftUIImage
          .resizable()
          .scaleEffect(appeared ? 1 : 0.92)
          .opacity(appeared ? 1 : 0)
          .onAppear {
            withCossistantAnimation(.easeOut(duration: 0.25)) {
              appeared = true
            }
          }
      }
      .buttonStyle(HapticButtonStyle())
    } else if failed {
      failurePlaceholder
    } else {
      placeholder
    }
  }

  // MARK: - Loading

  private func load() async {
    if loaded != nil { return }
    failed = false

    guard let url = URL(string: image.url) else { failed = true; return }

    if let cached = ImageThumbnailCache.shared[url] {
      loaded = cached
      return
    }

    do {
      // Download to a temporary file so ImageIO can downsample from disk
      // without materializing the full image payload in RAM.
      let (fileURL, _) = try await URLSession.shared.download(from: url)
      try Task.checkCancellation()
      let result = await Task.detached(priority: .userInitiated) {
        CachedImage.downsample(fileURL: fileURL, maxPixelSize: 440)
      }.value
      try? FileManager.default.removeItem(at: fileURL)
      guard let result else { failed = true; return }
      ImageThumbnailCache.shared[url] = result
      loaded = result
    } catch is CancellationError {
      return
    } catch {
      failed = true
    }
  }

  // MARK: - Placeholders

  private var placeholder: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(.secondary.opacity(0.08))
      .overlay {
        ProgressView()
          .tint(.secondary)
      }
  }

  private var failurePlaceholder: some View {
    RoundedRectangle(cornerRadius: 12)
      .fill(.secondary.opacity(0.08))
      .overlay {
        VStack(spacing: 6) {
          Image(systemSymbol: .photoFill)
            .foregroundStyle(.tertiary)
          Button(R.string(.retry)) { loadAttempt += 1 }
            .font(.caption2)
            .buttonStyle(HapticButtonStyle(haptic: .retry))
        }
      }
  }
}

// MARK: - Cached Thumbnail

/// Holds a downsampled SwiftUI image and the original pixel dimensions for aspect ratio.
/// @unchecked Sendable: Image is an immutable value type. Instances are created on a
/// detached task and then only read from MainActor — no shared mutable state.
private struct CachedImage: @unchecked Sendable {
  let originalSize: CGSize
  let swiftUIImage: Image

  /// Decodes and downsamples from a file URL in a single pass using ImageIO.
  /// Never materializes the full bitmap — decodes directly into a thumbnail buffer.
  static func downsample(fileURL: URL, maxPixelSize: CGFloat) -> CachedImage? {
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }

    // Read original dimensions without decoding
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
          let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat,
          pixelWidth > 0, pixelHeight > 0 else { return nil }

    let originalSize = CGSize(width: pixelWidth, height: pixelHeight)

    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      kCGImageSourceShouldCacheImmediately: true,
    ]

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      return nil
    }

    #if canImport(UIKit)
    let image = Image(uiImage: UIImage(cgImage: cgImage))
    #elseif canImport(AppKit)
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    let image = Image(nsImage: nsImage)
    #endif

    return CachedImage(originalSize: originalSize, swiftUIImage: image)
  }
}

// MARK: - In-Memory Cache

/// Process-wide cache for decoded chat image thumbnails.
private final class ImageThumbnailCache: Sendable {
  static let shared = ImageThumbnailCache()
  // NSCache is thread-safe internally; nonisolated(unsafe) silences the Sendable diagnostic.
  nonisolated(unsafe) private let cache = NSCache<NSURL, Box>()

  private init() {
    cache.countLimit = 80
  }

  subscript(url: URL) -> CachedImage? {
    get { cache.object(forKey: url as NSURL)?.value }
    set {
      if let value = newValue {
        cache.setObject(Box(value), forKey: url as NSURL)
      } else {
        cache.removeObject(forKey: url as NSURL)
      }
    }
  }

  /// NSCache requires reference-type values.
  private final class Box: Sendable {
    let value: CachedImage
    init(_ value: CachedImage) { self.value = value }
  }
}
