import Foundation

public struct ClipboardImage: Equatable, Sendable {
  public var data: Data
  public var contentType: String
  public var fileExtension: String

  public init(data: Data, contentType: String = "image/png", fileExtension: String = "png") {
    self.data = data
    self.contentType = contentType
    self.fileExtension = fileExtension
  }

  public var isImage: Bool {
    contentType.lowercased().hasPrefix("image/")
  }
}

public struct UploadResult: Equatable, Sendable {
  public var provider: UploadProviderKind
  public var publicURL: URL
  public var bytes: Int
  public var createdAt: Date

  public init(provider: UploadProviderKind, publicURL: URL, bytes: Int, createdAt: Date = Date()) {
    self.provider = provider
    self.publicURL = publicURL
    self.bytes = bytes
    self.createdAt = createdAt
  }
}

public enum UploadError: LocalizedError, Equatable {
  case missingImage
  case missingCredential(String)
  case invalidConfiguration(String)
  case invalidResponse(String)
  case commandFailed(String)

  public var errorDescription: String? {
    switch self {
    case .missingImage:
      return "No supported file found in the clipboard."
    case .missingCredential(let label):
      return "Missing \(label)."
    case .invalidConfiguration(let message):
      return message
    case .invalidResponse(let message):
      return message
    case .commandFailed(let message):
      return message
    }
  }
}
