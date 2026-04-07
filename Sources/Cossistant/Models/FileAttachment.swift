import Foundation

/// A file staged for upload, before or during sending.
public struct FileAttachment: Identifiable, Sendable {
  public let id: UUID
  public let data: Data
  public let fileName: String
  public let contentType: String
  public let isImage: Bool

  public var fileSizeBytes: Int { data.count }

  public init(data: Data, fileName: String, contentType: String) {
    self.id = UUID()
    self.data = data
    self.fileName = fileName
    self.contentType = contentType
    self.isImage = contentType.hasPrefix("image/")
  }
}

// MARK: - Validation

enum AttachmentValidationError: LocalizedError {
  case fileTooLarge(fileName: String, maxMB: Int)
  case unsupportedType(fileName: String)
  case tooManyFiles(max: Int)

  var errorDescription: String? {
    switch self {
    case .fileTooLarge(let name, let max):
      R.string(.attachment_error_too_large, name, "\(max)")
    case .unsupportedType(let name):
      R.string(.attachment_error_unsupported, name)
    case .tooManyFiles(let max):
      R.string(.attachment_error_too_many, "\(max)")
    }
  }
}
