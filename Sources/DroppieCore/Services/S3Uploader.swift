import CryptoKit
import Foundation

public final class S3Uploader: Sendable {
  private let httpClient: HTTPClient
  private let processRunner: ProcessRunning
  private let fileNameFactory: FileNameFactory
  private let now: @Sendable () -> Date

  public init(
    httpClient: HTTPClient,
    processRunner: ProcessRunning,
    fileNameFactory: FileNameFactory = FileNameFactory(),
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.httpClient = httpClient
    self.processRunner = processRunner
    self.fileNameFactory = fileNameFactory
    self.now = now
  }

  public func upload(image: ClipboardImage, settings: ProviderSettings, credentials: ProviderCredentials) async throws -> UploadResult {
    if settings.s3AuthMode == .awsProfile {
      return try await S3CompatibleUploader(processRunner: processRunner, fileNameFactory: fileNameFactory)
        .upload(image: image, settings: settings)
    }

    let bucket = settings.s3Bucket.trimmedDroppie
    guard !bucket.isEmpty else {
      throw UploadError.invalidConfiguration("Bucket is required.")
    }

    guard let publicBaseURL = URL(string: settings.s3PublicBaseURL.trimmedDroppie), publicBaseURL.scheme != nil else {
      throw UploadError.invalidConfiguration("Public base URL is required.")
    }

    guard let accessKeyID = credentials.accessKeyID?.nilIfBlankDroppie else {
      throw UploadError.missingCredential("Access Key ID")
    }

    guard let secretAccessKey = credentials.secretAccessKey?.nilIfBlankDroppie else {
      throw UploadError.missingCredential("Secret Access Key")
    }

    let prefix = settings.s3KeyPrefix.trimmedDroppie.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let fileName = fileNameFactory.makeFileName(extension: image.fileExtension)
    let objectKey = prefix.isEmpty ? fileName : "\(prefix)/\(fileName)"
    let target = try uploadTarget(settings: settings, bucket: bucket, objectKey: objectKey)
    let signedRequest = try signedPUTRequest(
      target: target,
      image: image,
      accessKeyID: accessKeyID,
      secretAccessKey: secretAccessKey,
      sessionToken: credentials.sessionToken?.nilIfBlankDroppie
    )

    let (data, response) = try await httpClient.upload(for: signedRequest, from: image.data)
    guard response.droppieIsSuccess else {
      let message = String(data: data, encoding: .utf8)?.nilIfBlankDroppie ?? "Upload failed with HTTP \(response.statusCode)."
      throw UploadError.invalidResponse(message)
    }

    return UploadResult(
      provider: settings.kind,
      publicURL: publicBaseURL.appendingPathComponentPreservingDirectory(objectKey),
      bytes: image.data.count
    )
  }

  private func uploadTarget(settings: ProviderSettings, bucket: String, objectKey: String) throws -> S3UploadTarget {
    switch settings.kind {
    case .amazonS3:
      let region = settings.s3Region.trimmedDroppie
      guard !region.isEmpty else {
        throw UploadError.invalidConfiguration("Region is required.")
      }

      let host = "\(bucket).s3.\(region).amazonaws.com"
      return S3UploadTarget(
        url: URL(string: "https://\(host)/\(Self.encodePath(objectKey))")!,
        host: host,
        canonicalURI: "/\(Self.encodePath(objectKey))",
        region: region
      )

    case .cloudflareR2:
      let accountID = settings.cloudflareAccountID.trimmedDroppie
      guard !accountID.isEmpty else {
        throw UploadError.invalidConfiguration("Cloudflare account ID is required.")
      }

      let host = "\(accountID).r2.cloudflarestorage.com"
      let path = "\(bucket)/\(objectKey)"
      return S3UploadTarget(
        url: URL(string: "https://\(host)/\(Self.encodePath(path))")!,
        host: host,
        canonicalURI: "/\(Self.encodePath(path))",
        region: "auto"
      )

    case .s3Compatible:
      guard let endpoint = URL(string: settings.s3EndpointURL.trimmedDroppie), let host = endpoint.host else {
        throw UploadError.invalidConfiguration("Endpoint URL is required.")
      }

      let region = settings.s3Region.nilIfBlankDroppie ?? "auto"
      let basePath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let path = [basePath, bucket, objectKey].filter { !$0.isEmpty }.joined(separator: "/")
      var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
      components?.path = "/\(Self.encodePath(path))"
      guard let url = components?.url else {
        throw UploadError.invalidConfiguration("Invalid endpoint URL.")
      }
      return S3UploadTarget(
        url: url,
        host: host,
        canonicalURI: "/\(Self.encodePath(path))",
        region: region
      )

    case .hereNow, .imgur, .googleDrive, .dropbox:
      throw UploadError.invalidConfiguration("Invalid S3 provider.")
    }
  }

  private func signedPUTRequest(
    target: S3UploadTarget,
    image: ClipboardImage,
    accessKeyID: String,
    secretAccessKey: String,
    sessionToken: String?
  ) throws -> URLRequest {
    let signingDate = now()
    let timestamp = Self.timestampFormatter.string(from: signingDate)
    let dateStamp = Self.dateFormatter.string(from: signingDate)
    let payloadHash = Self.hexSHA256(image.data)
    var headers = [
      "content-type": image.contentType,
      "host": target.host,
      "x-amz-content-sha256": payloadHash,
      "x-amz-date": timestamp
    ]

    if let sessionToken {
      headers["x-amz-security-token"] = sessionToken
    }

    let signedHeaderNames = headers.keys.sorted()
    let canonicalHeaders = signedHeaderNames
      .map { "\($0):\(headers[$0]!.trimmingCharacters(in: .whitespacesAndNewlines))" }
      .joined(separator: "\n") + "\n"
    let signedHeaders = signedHeaderNames.joined(separator: ";")
    let canonicalRequest = [
      "PUT",
      target.canonicalURI,
      "",
      canonicalHeaders,
      signedHeaders,
      payloadHash
    ].joined(separator: "\n")

    let credentialScope = "\(dateStamp)/\(target.region)/s3/aws4_request"
    let stringToSign = [
      "AWS4-HMAC-SHA256",
      timestamp,
      credentialScope,
      Self.hexSHA256(Data(canonicalRequest.utf8))
    ].joined(separator: "\n")
    let signingKey = Self.signingKey(secretAccessKey: secretAccessKey, dateStamp: dateStamp, region: target.region)
    let signature = Self.hexHMAC(key: signingKey, message: stringToSign)

    var request = URLRequest(url: target.url)
    request.httpMethod = "PUT"
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    request.setValue(
      "AWS4-HMAC-SHA256 Credential=\(accessKeyID)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)",
      forHTTPHeaderField: "authorization"
    )
    return request
  }

  private static func encodePath(_ path: String) -> String {
    path
      .split(separator: "/", omittingEmptySubsequences: false)
      .map { segment in
        String(segment).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(charactersIn: "?%#[]@!$&'()*+,;=")) ?? String(segment)
      }
      .joined(separator: "/")
  }

  private static func hexSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func signingKey(secretAccessKey: String, dateStamp: String, region: String) -> Data {
    let dateKey = hmac(key: Data("AWS4\(secretAccessKey)".utf8), message: dateStamp)
    let dateRegionKey = hmac(key: dateKey, message: region)
    let dateRegionServiceKey = hmac(key: dateRegionKey, message: "s3")
    return hmac(key: dateRegionServiceKey, message: "aws4_request")
  }

  private static func hmac(key: Data, message: String) -> Data {
    let code = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: key))
    return Data(code)
  }

  private static func hexHMAC(key: Data, message: String) -> String {
    hmac(key: key, message: message).map { String(format: "%02x", $0) }.joined()
  }

  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    return formatter
  }()

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd"
    return formatter
  }()
}

private struct S3UploadTarget {
  var url: URL
  var host: String
  var canonicalURI: String
  var region: String
}

private extension CharacterSet {
  func subtracting(charactersIn string: String) -> CharacterSet {
    var copy = self
    copy.remove(charactersIn: string)
    return copy
  }
}
