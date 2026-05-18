import Foundation

public enum UploadProviderKind: String, Codable, Sendable, Identifiable {
  case hereNow
  case imgur
  case amazonS3
  case cloudflareR2
  case googleDrive
  case dropbox
  case s3Compatible

  public var id: String { rawValue }

  public static var allCases: [UploadProviderKind] {
    [.hereNow, .imgur, .amazonS3, .cloudflareR2, .googleDrive, .dropbox]
  }

  public var title: String {
    switch self {
    case .hereNow:
      return "here.now"
    case .imgur:
      return "Imgur"
    case .amazonS3:
      return "Amazon S3"
    case .cloudflareR2:
      return "Cloudflare R2"
    case .googleDrive:
      return "Google Drive"
    case .dropbox:
      return "Dropbox"
    case .s3Compatible:
      return "S3-compatible"
    }
  }

  public var credentialLabel: String? {
    switch self {
    case .hereNow:
      return "API key"
    case .imgur:
      return "Client ID"
    case .googleDrive:
      return "Access token"
    case .dropbox:
      return "Access token"
    case .amazonS3, .cloudflareR2, .s3Compatible:
      return nil
    }
  }
}
