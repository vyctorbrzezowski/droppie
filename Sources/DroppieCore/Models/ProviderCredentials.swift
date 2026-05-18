import Foundation

public struct ProviderCredentials: Equatable, Sendable {
  public var primary: String?
  public var accessKeyID: String?
  public var secretAccessKey: String?
  public var sessionToken: String?

  public init(
    primary: String? = nil,
    accessKeyID: String? = nil,
    secretAccessKey: String? = nil,
    sessionToken: String? = nil
  ) {
    self.primary = primary
    self.accessKeyID = accessKeyID
    self.secretAccessKey = secretAccessKey
    self.sessionToken = sessionToken
  }
}
