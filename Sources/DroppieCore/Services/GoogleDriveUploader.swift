import Foundation

public final class GoogleDriveUploader: Sendable {
  private let httpClient: HTTPClient
  private let fileNameFactory: FileNameFactory

  public init(httpClient: HTTPClient, fileNameFactory: FileNameFactory = FileNameFactory()) {
    self.httpClient = httpClient
    self.fileNameFactory = fileNameFactory
  }

  public func upload(image: ClipboardImage, settings: ProviderSettings, accessToken: String?) async throws -> UploadResult {
    guard let accessToken = accessToken?.nilIfBlankDroppie else {
      throw UploadError.missingCredential("Google Drive access token")
    }

    guard let baseURL = URL(string: settings.googleDriveAPIBaseURL.trimmedDroppie), baseURL.scheme != nil else {
      throw UploadError.invalidConfiguration("Invalid Google Drive API URL.")
    }

    let fileName = fileNameFactory.makeFileName(extension: image.fileExtension)
    let boundary = "DroppieBoundary-\(UUID().uuidString)"
    let metadata = GoogleDriveCreateMetadata(
      name: fileName,
      mimeType: image.contentType,
      parents: settings.googleDriveFolderID.nilIfBlankDroppie.map { [$0] }
    )
    let body = try multipartRelatedBody(metadata: metadata, file: image, boundary: boundary)
    let uploadURL = try Self.url(
      baseURL: baseURL,
      path: "/upload/drive/v3/files",
      queryItems: [
        URLQueryItem(name: "uploadType", value: "multipart"),
        URLQueryItem(name: "fields", value: "id,webViewLink,webContentLink")
      ]
    )

    var uploadRequest = URLRequest(url: uploadURL)
    uploadRequest.httpMethod = "POST"
    uploadRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    uploadRequest.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    let (uploadData, uploadResponse) = try await httpClient.upload(for: uploadRequest, from: body)
    guard uploadResponse.droppieIsSuccess else {
      throw UploadError.invalidResponse(Self.message(from: uploadData, fallback: "Google Drive upload failed with HTTP \(uploadResponse.statusCode)."))
    }

    let uploaded = try JSONDecoder().decode(GoogleDriveFile.self, from: uploadData)
    try await makePublic(fileID: uploaded.id, baseURL: baseURL, accessToken: accessToken)
    let file = try await fetchFile(fileID: uploaded.id, baseURL: baseURL, accessToken: accessToken)

    guard let publicURL = URL(string: file.webViewLink ?? file.webContentLink ?? "") else {
      throw UploadError.invalidResponse("Google Drive did not return a public file link.")
    }

    return UploadResult(provider: .googleDrive, publicURL: publicURL, bytes: image.data.count)
  }

  private func makePublic(fileID: String, baseURL: URL, accessToken: String) async throws {
    let permissionsURL = try Self.url(baseURL: baseURL, path: "/drive/v3/files/\(fileID)/permissions")
    var request = URLRequest(url: permissionsURL)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(GoogleDrivePermission(role: "reader", type: "anyone"))

    let (data, response) = try await httpClient.data(for: request)
    guard response.droppieIsSuccess else {
      throw UploadError.invalidResponse(Self.message(from: data, fallback: "Google Drive sharing failed with HTTP \(response.statusCode)."))
    }
  }

  private func fetchFile(fileID: String, baseURL: URL, accessToken: String) async throws -> GoogleDriveFile {
    let fileURL = try Self.url(
      baseURL: baseURL,
      path: "/drive/v3/files/\(fileID)",
      queryItems: [URLQueryItem(name: "fields", value: "id,webViewLink,webContentLink")]
    )
    var request = URLRequest(url: fileURL)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await httpClient.data(for: request)
    guard response.droppieIsSuccess else {
      throw UploadError.invalidResponse(Self.message(from: data, fallback: "Google Drive link fetch failed with HTTP \(response.statusCode)."))
    }

    return try JSONDecoder().decode(GoogleDriveFile.self, from: data)
  }

  private func multipartRelatedBody(metadata: GoogleDriveCreateMetadata, file: ClipboardImage, boundary: String) throws -> Data {
    var body = Data()
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(Data("Content-Type: application/json; charset=UTF-8\r\n\r\n".utf8))
    body.append(try JSONEncoder().encode(metadata))
    body.append(Data("\r\n--\(boundary)\r\n".utf8))
    body.append(Data("Content-Type: \(file.contentType)\r\n\r\n".utf8))
    body.append(file.data)
    body.append(Data("\r\n--\(boundary)--\r\n".utf8))
    return body
  }

  private static func url(baseURL: URL, path: String, queryItems: [URLQueryItem] = []) throws -> URL {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path = path
    components?.queryItems = queryItems.isEmpty ? nil : queryItems
    guard let url = components?.url else {
      throw UploadError.invalidConfiguration("Invalid Google Drive API URL.")
    }
    return url
  }

  private static func message(from data: Data, fallback: String) -> String {
    String(data: data, encoding: .utf8)?.nilIfBlankDroppie ?? fallback
  }
}

private struct GoogleDriveCreateMetadata: Encodable {
  var name: String
  var mimeType: String
  var parents: [String]?
}

private struct GoogleDrivePermission: Encodable {
  var role: String
  var type: String
}

private struct GoogleDriveFile: Decodable {
  var id: String
  var webViewLink: String?
  var webContentLink: String?
}
