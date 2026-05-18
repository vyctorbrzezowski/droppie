import CryptoKit
import Foundation

public final class HereNowUploader: Sendable {
  private let httpClient: HTTPClient
  private let fileNameFactory: FileNameFactory

  public init(httpClient: HTTPClient, fileNameFactory: FileNameFactory = FileNameFactory()) {
    self.httpClient = httpClient
    self.fileNameFactory = fileNameFactory
  }

  public func upload(image: ClipboardImage, settings: ProviderSettings, apiKey: String?) async throws -> UploadResult {
    guard let baseURL = URL(string: settings.hereNowAPIBaseURL.trimmedDroppie), baseURL.scheme != nil else {
      throw UploadError.invalidConfiguration("Invalid here.now API URL.")
    }

    let fileName = fileNameFactory.makeFileName(extension: image.fileExtension)
    let hash = SHA256.hash(data: image.data).map { String(format: "%02x", $0) }.joined()
    let publishBody = HereNowPublishRequest(
      files: [
        .init(path: fileName, size: image.data.count, contentType: image.contentType, hash: hash)
      ],
      viewer: .init(title: fileName, description: "Uploaded by Droppie")
    )

    var publishRequest = URLRequest(url: baseURL.appendingPathComponent("/api/v1/publish"))
    publishRequest.httpMethod = "POST"
    publishRequest.setValue("application/json", forHTTPHeaderField: "content-type")
    publishRequest.setValue("droppie/macos", forHTTPHeaderField: "X-HereNow-Client")
    if let apiKey = apiKey?.nilIfBlankDroppie {
      publishRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
    publishRequest.httpBody = try JSONEncoder().encode(publishBody)

    let (publishData, publishResponse) = try await httpClient.data(for: publishRequest)
    guard publishResponse.droppieIsSuccess else {
      throw UploadError.invalidResponse("here.now create failed with HTTP \(publishResponse.statusCode).")
    }

    let publish = try JSONDecoder().decode(HereNowPublishResponse.self, from: publishData)

    for upload in publish.upload.uploads {
      var putRequest = URLRequest(url: upload.url)
      putRequest.httpMethod = upload.method
      for (name, value) in upload.headers {
        putRequest.setValue(value, forHTTPHeaderField: name)
      }

      let (_, putResponse) = try await httpClient.upload(for: putRequest, from: image.data)
      guard putResponse.droppieIsSuccess else {
        throw UploadError.invalidResponse("here.now upload failed with HTTP \(putResponse.statusCode).")
      }
    }

    var finalizeRequest = URLRequest(url: publish.upload.finalizeUrl)
    finalizeRequest.httpMethod = "POST"
    finalizeRequest.setValue("application/json", forHTTPHeaderField: "content-type")
    if let apiKey = apiKey?.nilIfBlankDroppie {
      finalizeRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
    finalizeRequest.httpBody = try JSONEncoder().encode(HereNowFinalizeRequest(versionId: publish.upload.versionId))

    let (_, finalizeResponse) = try await httpClient.data(for: finalizeRequest)
    guard finalizeResponse.droppieIsSuccess else {
      throw UploadError.invalidResponse("here.now finalize failed with HTTP \(finalizeResponse.statusCode).")
    }

    guard let siteURL = URL(string: publish.siteUrl) else {
      throw UploadError.invalidResponse("here.now returned an invalid site URL.")
    }

    return UploadResult(
      provider: .hereNow,
      publicURL: siteURL.appendingPathComponentPreservingDirectory(fileName),
      bytes: image.data.count
    )
  }
}

private struct HereNowPublishRequest: Encodable {
  var files: [File]
  var viewer: Viewer

  struct File: Encodable {
    var path: String
    var size: Int
    var contentType: String
    var hash: String
  }

  struct Viewer: Encodable {
    var title: String
    var description: String
  }
}

private struct HereNowFinalizeRequest: Encodable {
  var versionId: String
}

private struct HereNowPublishResponse: Decodable {
  var slug: String
  var siteUrl: String
  var upload: Upload

  struct Upload: Decodable {
    var versionId: String
    var uploads: [UploadItem]
    var finalizeUrl: URL
  }

  struct UploadItem: Decodable {
    var path: String
    var method: String
    var url: URL
    var headers: [String: String]
  }
}
