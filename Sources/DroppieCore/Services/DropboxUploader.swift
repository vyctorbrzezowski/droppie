import Foundation

public final class DropboxUploader: Sendable {
  private let httpClient: HTTPClient
  private let fileNameFactory: FileNameFactory

  public init(httpClient: HTTPClient, fileNameFactory: FileNameFactory = FileNameFactory()) {
    self.httpClient = httpClient
    self.fileNameFactory = fileNameFactory
  }

  public func upload(image: ClipboardImage, settings: ProviderSettings, accessToken: String?) async throws -> UploadResult {
    guard let accessToken = accessToken?.nilIfBlankDroppie else {
      throw UploadError.missingCredential("Dropbox access token")
    }

    guard let apiBaseURL = URL(string: settings.dropboxAPIBaseURL.trimmedDroppie), apiBaseURL.scheme != nil else {
      throw UploadError.invalidConfiguration("Invalid Dropbox API URL.")
    }

    guard let contentBaseURL = URL(string: settings.dropboxContentAPIBaseURL.trimmedDroppie), contentBaseURL.scheme != nil else {
      throw UploadError.invalidConfiguration("Invalid Dropbox content API URL.")
    }

    let fileName = fileNameFactory.makeFileName(extension: image.fileExtension)
    let pathPrefix = settings.dropboxPathPrefix.nilIfBlankDroppie ?? "/Droppie"
    let path = normalizedPath(prefix: pathPrefix, fileName: fileName)
    let uploadURL = contentBaseURL.appendingPathComponent("/2/files/upload")
    let uploadArg = DropboxUploadArg(path: path, mode: "add", autorename: true, mute: true)

    var uploadRequest = URLRequest(url: uploadURL)
    uploadRequest.httpMethod = "POST"
    uploadRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
    uploadRequest.setValue(String(data: try JSONEncoder().encode(uploadArg), encoding: .utf8), forHTTPHeaderField: "Dropbox-API-Arg")

    let (uploadData, uploadResponse) = try await httpClient.upload(for: uploadRequest, from: image.data)
    guard uploadResponse.droppieIsSuccess else {
      throw UploadError.invalidResponse(Self.message(from: uploadData, fallback: "Dropbox upload failed with HTTP \(uploadResponse.statusCode)."))
    }

    let uploaded = try JSONDecoder().decode(DropboxUploadResponse.self, from: uploadData)
    let publicURL = try await sharedLink(path: uploaded.pathDisplay ?? path, apiBaseURL: apiBaseURL, accessToken: accessToken)

    return UploadResult(provider: .dropbox, publicURL: publicURL, bytes: image.data.count)
  }

  private func sharedLink(path: String, apiBaseURL: URL, accessToken: String) async throws -> URL {
    let sharedLinkURL = apiBaseURL.appendingPathComponent("/2/sharing/create_shared_link_with_settings")
    var request = URLRequest(url: sharedLinkURL)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(DropboxCreateSharedLinkArg(path: path))

    let (data, response) = try await httpClient.data(for: request)
    if response.droppieIsSuccess {
      let link = try JSONDecoder().decode(DropboxSharedLink.self, from: data)
      guard let url = URL(string: link.url) else {
        throw UploadError.invalidResponse("Dropbox returned an invalid shared link.")
      }
      return url
    }

    if response.statusCode == 409 {
      if let existing = try await existingSharedLink(path: path, apiBaseURL: apiBaseURL, accessToken: accessToken) {
        return existing
      }
    }

    throw UploadError.invalidResponse(Self.message(from: data, fallback: "Dropbox sharing failed with HTTP \(response.statusCode)."))
  }

  private func existingSharedLink(path: String, apiBaseURL: URL, accessToken: String) async throws -> URL? {
    let listURL = apiBaseURL.appendingPathComponent("/2/sharing/list_shared_links")
    var request = URLRequest(url: listURL)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(DropboxListSharedLinksArg(path: path, directOnly: true))

    let (data, response) = try await httpClient.data(for: request)
    guard response.droppieIsSuccess else {
      return nil
    }

    let links = try JSONDecoder().decode(DropboxSharedLinks.self, from: data)
    return links.links.compactMap { URL(string: $0.url) }.first
  }

  private func normalizedPath(prefix: String, fileName: String) -> String {
    let trimmedPrefix = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return "/\([trimmedPrefix, fileName].filter { !$0.isEmpty }.joined(separator: "/"))"
  }

  private static func message(from data: Data, fallback: String) -> String {
    String(data: data, encoding: .utf8)?.nilIfBlankDroppie ?? fallback
  }
}

private struct DropboxUploadArg: Encodable {
  var path: String
  var mode: String
  var autorename: Bool
  var mute: Bool
}

private struct DropboxUploadResponse: Decodable {
  var pathDisplay: String?

  enum CodingKeys: String, CodingKey {
    case pathDisplay = "path_display"
  }
}

private struct DropboxCreateSharedLinkArg: Encodable {
  var path: String
}

private struct DropboxListSharedLinksArg: Encodable {
  var path: String
  var directOnly: Bool

  enum CodingKeys: String, CodingKey {
    case path
    case directOnly = "direct_only"
  }
}

private struct DropboxSharedLinks: Decodable {
  var links: [DropboxSharedLink]
}

private struct DropboxSharedLink: Decodable {
  var url: String
}
