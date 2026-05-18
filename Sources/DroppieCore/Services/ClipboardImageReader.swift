import AppKit
import Foundation
import UniformTypeIdentifiers

public protocol ClipboardImageReading: Sendable {
  func readImage() throws -> ClipboardImage
}

public struct PasteboardClipboardImageReader: ClipboardImageReading, @unchecked Sendable {
  private let pasteboard: NSPasteboard

  public init(pasteboard: NSPasteboard = .general) {
    self.pasteboard = pasteboard
  }

  public func readImage() throws -> ClipboardImage {
    if let png = pasteboard.data(forType: .png), !png.isEmpty {
      return ClipboardImage(data: png, contentType: "image/png", fileExtension: "png")
    }

    if let tiff = pasteboard.data(forType: .tiff),
       let image = NSImage(data: tiff),
       let png = image.droppiePNGData() {
      return ClipboardImage(data: png, contentType: "image/png", fileExtension: "png")
    }

    if let fileURL = readImageFileURL(),
       let image = NSImage(contentsOf: fileURL),
       let png = image.droppiePNGData() {
      return ClipboardImage(data: png, contentType: "image/png", fileExtension: "png")
    }

    throw UploadError.missingImage
  }

  private func readImageFileURL() -> URL? {
    guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
      return nil
    }

    return items.first { url in
      guard let resourceType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
        return false
      }
      return resourceType.conforms(to: .image)
    }
  }
}

public struct ImageFileReader: Sendable {
  public init() {}

  public func readImage(at url: URL) throws -> ClipboardImage {
    let values = try url.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey])
    guard values.isRegularFile == true else {
      throw UploadError.missingImage
    }

    let data = try Data(contentsOf: url)
    guard !data.isEmpty else {
      throw UploadError.missingImage
    }

    let fileExtension = url.pathExtension.nilIfBlankDroppie ?? "png"
    let contentType = values.contentType?.preferredMIMEType
      ?? UTType(filenameExtension: fileExtension)?.preferredMIMEType
      ?? "application/octet-stream"

    return ClipboardImage(data: data, contentType: contentType, fileExtension: fileExtension)
  }
}

public extension NSImage {
  func droppiePNGData() -> Data? {
    guard let tiffRepresentation else {
      return nil
    }

    guard let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
      return nil
    }

    return bitmap.representation(using: .png, properties: [:])
  }
}
