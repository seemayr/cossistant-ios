import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import SFSafeSymbols
import CoreTransferable

/// Raw image data loaded via Transferable from PhotosPicker.
/// Apple docs: "Image only supports PNG through its Transferable conformance" —
/// so we use a custom type with DataRepresentation to get the actual image bytes.
private struct ImageFileData: Transferable {
  let data: Data

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(importedContentType: .image) { data in
      ImageFileData(data: data)
    }
  }
}

/// Menu button offering photo library and file picker options.
struct AttachmentPickerView: View {
  @Binding var attachments: [FileAttachment]
  @Binding var validationError: AttachmentValidationError?
  let onPickerWillPresent: () -> Void

  @State private var photoSelection: [PhotosPickerItem] = []
  @State private var isFileImporterPresented = false

  private var remainingSlots: Int {
    max(0, UploadConstants.maxFilesPerMessage - attachments.count)
  }

  var body: some View {
    Menu {
      photoPickerButton
      filePickerButton
    } label: {
      Image(systemSymbol: .plusCircleFill)
        .font(.title2)
        .foregroundStyle(remainingSlots > 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.4)))
    }
    .disabled(remainingSlots == 0)
    .photosPicker(
      isPresented: $isPhotosPickerPresented,
      selection: $photoSelection,
      maxSelectionCount: remainingSlots,
      matching: .images,
      preferredItemEncoding: .compatible
    )
    .fileImporter(
      isPresented: $isFileImporterPresented,
      allowedContentTypes: UploadConstants.importableTypes,
      allowsMultipleSelection: true
    ) { result in
      handleFileImport(result)
    }
    .onChange(of: photoSelection) { _, newValue in
      guard !newValue.isEmpty else { return }
      Task { await handlePhotoSelection(newValue) }
    }
  }

  @State private var isPhotosPickerPresented = false

  // MARK: - Menu Items

  private var photoPickerButton: some View {
    Button {
      onPickerWillPresent()
      isPhotosPickerPresented = true
    } label: {
      Label(R.string(.attachment_photo_library), systemSymbol: .photoOnRectangleAngled)
    }
    .disabled(remainingSlots == 0)
  }

  private var filePickerButton: some View {
    Button {
      onPickerWillPresent()
      isFileImporterPresented = true
    } label: {
      Label(R.string(.attachment_choose_file), systemSymbol: .doc)
    }
    .disabled(remainingSlots == 0)
  }

  // MARK: - Photo Handling

  private func handlePhotoSelection(_ selection: [PhotosPickerItem]) async {
    defer { photoSelection = [] }

    for item in selection {
      guard remainingSlots > 0 else {
        validationError = .tooManyFiles(max: UploadConstants.maxFilesPerMessage)
        break
      }

      guard let imageData = try? await item.loadTransferable(type: ImageFileData.self) else {
        continue
      }

      // Compress to JPEG for smaller uploads
      let compressed = compressToJPEG(imageData.data) ?? imageData.data
      let contentType = compressed != imageData.data ? "image/jpeg" : detectMIMEType(for: item)
      let fileName = compressed != imageData.data ? "photo.jpg" : (item.itemIdentifier ?? "photo")

      let attachment = FileAttachment(
        data: compressed,
        fileName: fileName,
        contentType: contentType
      )

      if let error = UploadConstants.validate(attachment) {
        validationError = error
      } else {
        attachments.append(attachment)
      }
    }
  }

  private func compressToJPEG(_ data: Data) -> Data? {
    #if canImport(UIKit)
    guard let image = UIImage(data: data) else { return nil }
    return image.jpegData(compressionQuality: UploadConstants.jpegCompressionQuality)
    #elseif canImport(AppKit)
    guard let image = NSImage(data: data),
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: UploadConstants.jpegCompressionQuality])
    #endif
  }

  private func detectMIMEType(for item: PhotosPickerItem) -> String {
    if let first = item.supportedContentTypes.first,
       let mime = first.preferredMIMEType {
      return mime
    }
    return "image/jpeg"
  }

  // MARK: - File Handling

  private func handleFileImport(_ result: Result<[URL], Error>) {
    guard case .success(let urls) = result else { return }

    let trimmed = Array(urls.prefix(remainingSlots))
    if urls.count > remainingSlots {
      validationError = .tooManyFiles(max: UploadConstants.maxFilesPerMessage)
    }

    for url in trimmed {
      guard url.startAccessingSecurityScopedResource() else { continue }
      defer { url.stopAccessingSecurityScopedResource() }

      guard let data = try? Data(contentsOf: url) else { continue }

      let utType = UTType(filenameExtension: url.pathExtension)
      let mimeType = utType?.preferredMIMEType ?? "application/octet-stream"

      let attachment = FileAttachment(
        data: data,
        fileName: url.lastPathComponent,
        contentType: mimeType
      )

      if let error = UploadConstants.validate(attachment) {
        validationError = error
      } else {
        attachments.append(attachment)
      }
    }
  }
}
