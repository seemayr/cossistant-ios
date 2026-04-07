import UniformTypeIdentifiers

enum UploadConstants {
  /// Maximum file size per attachment (5 MB), matching the web widget.
  static let maxFileSizeBytes = 5 * 1024 * 1024

  /// Maximum number of file attachments per message, matching the web widget.
  static let maxFilesPerMessage = 3

  /// JPEG compression quality for photo library images (0.0–1.0).
  /// 0.8 provides a good balance between quality and file size.
  static let jpegCompressionQuality: CGFloat = 0.8

  /// Allowed MIME types for upload, matching the web widget's upload-constants.ts.
  static let allowedMIMETypes: Set<String> = [
    "image/jpeg", "image/png", "image/gif", "image/webp",
    "application/pdf",
    "text/plain", "text/csv", "text/markdown",
    "application/zip",
  ]

  /// UTTypes for the .fileImporter modifier.
  static var importableTypes: [UTType] {
    var types: [UTType] = [
      .jpeg, .png, .gif, .webP,
      .pdf,
      .plainText, .commaSeparatedText,
      .zip,
    ]
    // Markdown is not a system UTType — create from extension
    if let md = UTType(filenameExtension: "md") {
      types.append(md)
    }
    return types
  }

  /// Validates a single attachment against size and MIME type constraints.
  static func validate(_ file: FileAttachment) -> AttachmentValidationError? {
    if file.fileSizeBytes > maxFileSizeBytes {
      return .fileTooLarge(fileName: file.fileName, maxMB: maxFileSizeBytes / (1024 * 1024))
    }
    if !allowedMIMETypes.contains(file.contentType) {
      return .unsupportedType(fileName: file.fileName)
    }
    return nil
  }
}
