import Foundation

public final class ImgurUploader: Sendable {
  private let httpClient: HTTPClient
  private let fileNameFactory: FileNameFactory

  public init(httpClient: HTTPClient, fileNameFactory: FileNameFactory = FileNameFactory()) {
    self.httpClient = httpClient
    self.fileNameFactory = fileNameFactory
  }

  public func upload(image: ClipboardImage, settings: ProviderSettings, clientID: String?) async throws -> UploadResult {
    guard image.isImage else {
      throw UploadError.invalidConfiguration("Imgur only supports image uploads.")
    }

    guard let clientID = clientID?.nilIfBlankDroppie else {
      throw UploadError.missingCredential("Imgur Client ID")
    }

    guard let baseURL = URL(string: settings.imgurAPIBaseURL.trimmedDroppie), baseURL.scheme != nil else {
      throw UploadError.invalidConfiguration("Invalid Imgur API URL.")
    }

    let fileName = fileNameFactory.makeFileName(extension: image.fileExtension)
    let multipart = MultipartFormData(parts: [
      .init(name: "image", fileName: fileName, contentType: image.contentType, data: image.data),
      .init(name: "type", contentType: "text/plain", data: Data("file".utf8))
    ])

    var request = URLRequest(url: baseURL.appendingPathComponent("/3/image"))
    request.httpMethod = "POST"
    request.setValue("Client-ID \(clientID)", forHTTPHeaderField: "Authorization")
    request.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")

    let (data, response) = try await httpClient.upload(for: request, from: multipart.body)
    guard response.droppieIsSuccess else {
      throw UploadError.invalidResponse("Imgur upload failed with HTTP \(response.statusCode).")
    }

    let decoded = try JSONDecoder().decode(ImgurUploadResponse.self, from: data)
    guard decoded.success, let publicURL = URL(string: decoded.data.link) else {
      throw UploadError.invalidResponse("Imgur returned an invalid image link.")
    }

    return UploadResult(provider: .imgur, publicURL: publicURL, bytes: image.data.count)
  }
}

private struct ImgurUploadResponse: Decodable {
  var success: Bool
  var data: ImageData

  struct ImageData: Decodable {
    var link: String
  }
}
