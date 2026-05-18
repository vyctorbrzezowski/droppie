import Foundation

public struct UploadHistoryEntry: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var publicURL: URL
  public var provider: UploadProviderKind
  public var bytes: Int
  public var createdAt: Date
  public var thumbnailData: Data?
  public var displayName: String?
  public var contentType: String?

  public init(
    id: UUID = UUID(),
    publicURL: URL,
    provider: UploadProviderKind,
    bytes: Int,
    createdAt: Date,
    thumbnailData: Data? = nil,
    displayName: String? = nil,
    contentType: String? = nil
  ) {
    self.id = id
    self.publicURL = publicURL
    self.provider = provider
    self.bytes = bytes
    self.createdAt = createdAt
    self.thumbnailData = thumbnailData
    self.displayName = displayName
    self.contentType = contentType
  }

  public init(result: UploadResult, thumbnailData: Data? = nil, displayName: String? = nil, contentType: String? = nil) {
    self.init(
      publicURL: result.publicURL,
      provider: result.provider,
      bytes: result.bytes,
      createdAt: result.createdAt,
      thumbnailData: thumbnailData,
      displayName: displayName,
      contentType: contentType
    )
  }
}

public final class UploadHistoryStore {
  private let defaults: UserDefaults
  private let key = "uploadHistory"
  private let limit: Int

  public init(defaults: UserDefaults = .standard, limit: Int = 100) {
    self.defaults = defaults
    self.limit = limit
  }

  public func load() -> [UploadHistoryEntry] {
    guard let data = defaults.data(forKey: key),
          let decoded = try? JSONDecoder().decode([UploadHistoryEntry].self, from: data) else {
      return []
    }

    return decoded
  }

  public func save(_ entries: [UploadHistoryEntry]) throws {
    let trimmed = Array(entries.prefix(limit))
    let data = try JSONEncoder().encode(trimmed)
    defaults.set(data, forKey: key)
  }

  public func clear() {
    defaults.removeObject(forKey: key)
  }
}
