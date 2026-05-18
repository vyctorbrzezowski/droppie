import Foundation

public enum S3AuthMode: String, CaseIterable, Codable, Identifiable, Sendable {
  case accessKeys
  case awsProfile

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .accessKeys:
      return "Access keys"
    case .awsProfile:
      return "AWS profile"
    }
  }
}

public struct ProviderSettings: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var kind: UploadProviderKind
  public var name: String
  public var copyLinkAfterUpload: Bool
  public var hereNowAPIBaseURL: String
  public var imgurAPIBaseURL: String
  public var s3Bucket: String
  public var s3Region: String
  public var s3EndpointURL: String
  public var s3PublicBaseURL: String
  public var s3KeyPrefix: String
  public var s3Profile: String
  public var s3AuthMode: S3AuthMode
  public var cloudflareAccountID: String
  public var googleDriveAPIBaseURL: String
  public var googleDriveFolderID: String
  public var dropboxAPIBaseURL: String
  public var dropboxContentAPIBaseURL: String
  public var dropboxPathPrefix: String

  enum CodingKeys: String, CodingKey {
    case id
    case kind
    case name
    case copyLinkAfterUpload
    case hereNowAPIBaseURL
    case imgurAPIBaseURL
    case s3Bucket
    case s3Region
    case s3EndpointURL
    case s3PublicBaseURL
    case s3KeyPrefix
    case s3Profile
    case s3AuthMode
    case cloudflareAccountID
    case googleDriveAPIBaseURL
    case googleDriveFolderID
    case dropboxAPIBaseURL
    case dropboxContentAPIBaseURL
    case dropboxPathPrefix
  }

  public init(
    id: UUID = UUID(),
    kind: UploadProviderKind,
    name: String? = nil,
    copyLinkAfterUpload: Bool = true,
    hereNowAPIBaseURL: String = "https://here.now",
    imgurAPIBaseURL: String = "https://api.imgur.com",
    s3Bucket: String = "",
    s3Region: String = "",
    s3EndpointURL: String = "",
    s3PublicBaseURL: String = "",
    s3KeyPrefix: String = "uploads",
    s3Profile: String = "",
    s3AuthMode: S3AuthMode = .accessKeys,
    cloudflareAccountID: String = "",
    googleDriveAPIBaseURL: String = "https://www.googleapis.com",
    googleDriveFolderID: String = "",
    dropboxAPIBaseURL: String = "https://api.dropboxapi.com",
    dropboxContentAPIBaseURL: String = "https://content.dropboxapi.com",
    dropboxPathPrefix: String = "/Droppie"
  ) {
    self.id = id
    self.kind = kind
    self.name = name ?? kind.title
    self.copyLinkAfterUpload = copyLinkAfterUpload
    self.hereNowAPIBaseURL = hereNowAPIBaseURL
    self.imgurAPIBaseURL = imgurAPIBaseURL
    self.s3Bucket = s3Bucket
    self.s3Region = s3Region
    self.s3EndpointURL = s3EndpointURL
    self.s3PublicBaseURL = s3PublicBaseURL
    self.s3KeyPrefix = s3KeyPrefix
    self.s3Profile = s3Profile
    self.s3AuthMode = s3AuthMode
    self.cloudflareAccountID = cloudflareAccountID
    self.googleDriveAPIBaseURL = googleDriveAPIBaseURL
    self.googleDriveFolderID = googleDriveFolderID
    self.dropboxAPIBaseURL = dropboxAPIBaseURL
    self.dropboxContentAPIBaseURL = dropboxContentAPIBaseURL
    self.dropboxPathPrefix = dropboxPathPrefix
  }

  public var requiresCredential: Bool {
    kind.credentialLabel != nil
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    kind = try container.decode(UploadProviderKind.self, forKey: .kind)
    name = try container.decode(String.self, forKey: .name)
    copyLinkAfterUpload = try container.decode(Bool.self, forKey: .copyLinkAfterUpload)
    hereNowAPIBaseURL = try container.decodeIfPresent(String.self, forKey: .hereNowAPIBaseURL) ?? "https://here.now"
    imgurAPIBaseURL = try container.decodeIfPresent(String.self, forKey: .imgurAPIBaseURL) ?? "https://api.imgur.com"
    s3Bucket = try container.decodeIfPresent(String.self, forKey: .s3Bucket) ?? ""
    s3Region = try container.decodeIfPresent(String.self, forKey: .s3Region) ?? ""
    s3EndpointURL = try container.decodeIfPresent(String.self, forKey: .s3EndpointURL) ?? ""
    s3PublicBaseURL = try container.decodeIfPresent(String.self, forKey: .s3PublicBaseURL) ?? ""
    s3KeyPrefix = try container.decodeIfPresent(String.self, forKey: .s3KeyPrefix) ?? "uploads"
    s3Profile = try container.decodeIfPresent(String.self, forKey: .s3Profile) ?? ""
    s3AuthMode = try container.decodeIfPresent(S3AuthMode.self, forKey: .s3AuthMode) ?? .accessKeys
    cloudflareAccountID = try container.decodeIfPresent(String.self, forKey: .cloudflareAccountID) ?? ""
    googleDriveAPIBaseURL = try container.decodeIfPresent(String.self, forKey: .googleDriveAPIBaseURL) ?? "https://www.googleapis.com"
    googleDriveFolderID = try container.decodeIfPresent(String.self, forKey: .googleDriveFolderID) ?? ""
    dropboxAPIBaseURL = try container.decodeIfPresent(String.self, forKey: .dropboxAPIBaseURL) ?? "https://api.dropboxapi.com"
    dropboxContentAPIBaseURL = try container.decodeIfPresent(String.self, forKey: .dropboxContentAPIBaseURL) ?? "https://content.dropboxapi.com"
    dropboxPathPrefix = try container.decodeIfPresent(String.self, forKey: .dropboxPathPrefix) ?? "/Droppie"
  }
}
