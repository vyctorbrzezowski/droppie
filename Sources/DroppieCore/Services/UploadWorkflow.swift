import Foundation

public final class UploadWorkflow: Sendable {
  private let imageReader: ClipboardImageReading
  private let fileReader: ImageFileReader
  private let linkWriter: ClipboardLinkWriting
  private let httpClient: HTTPClient
  private let processRunner: ProcessRunning

  public init(
    imageReader: ClipboardImageReading,
    linkWriter: ClipboardLinkWriting,
    fileReader: ImageFileReader = ImageFileReader(),
    httpClient: HTTPClient = URLSessionHTTPClient(),
    processRunner: ProcessRunning = ProcessRunner()
  ) {
    self.imageReader = imageReader
    self.fileReader = fileReader
    self.linkWriter = linkWriter
    self.httpClient = httpClient
    self.processRunner = processRunner
  }

  public func uploadClipboard(settings: ProviderSettings, credential: String?) async throws -> UploadResult {
    let image = try readClipboardImage()
    return try await uploadImage(image, settings: settings, credential: credential)
  }

  public func uploadClipboard(settings: ProviderSettings, credentials: ProviderCredentials) async throws -> UploadResult {
    let image = try readClipboardImage()
    return try await uploadImage(image, settings: settings, credentials: credentials)
  }

  public func readClipboardImage() throws -> ClipboardImage {
    try imageReader.readImage()
  }

  public func uploadFile(
    at url: URL,
    settings: ProviderSettings,
    credential: String?,
    copyResultToClipboard: Bool = true
  ) async throws -> UploadResult {
    let image = try readFile(at: url)
    return try await uploadImage(
      image,
      settings: settings,
      credential: credential,
      copyResultToClipboard: copyResultToClipboard
    )
  }

  public func uploadFile(
    at url: URL,
    settings: ProviderSettings,
    credentials: ProviderCredentials,
    copyResultToClipboard: Bool = true
  ) async throws -> UploadResult {
    let image = try readFile(at: url)
    return try await uploadImage(
      image,
      settings: settings,
      credentials: credentials,
      copyResultToClipboard: copyResultToClipboard
    )
  }

  public func readFile(at url: URL) throws -> ClipboardImage {
    try fileReader.readImage(at: url)
  }

  public func uploadImage(
    _ image: ClipboardImage,
    settings: ProviderSettings,
    credential: String?,
    copyResultToClipboard: Bool = true
  ) async throws -> UploadResult {
    try await uploadImage(
      image,
      settings: settings,
      credentials: ProviderCredentials(primary: credential),
      copyResultToClipboard: copyResultToClipboard
    )
  }

  public func uploadImage(
    _ image: ClipboardImage,
    settings: ProviderSettings,
    credentials: ProviderCredentials,
    copyResultToClipboard: Bool = true
  ) async throws -> UploadResult {
    let result: UploadResult

    switch settings.kind {
    case .hereNow:
      result = try await HereNowUploader(httpClient: httpClient).upload(image: image, settings: settings, apiKey: credentials.primary)
    case .imgur:
      result = try await ImgurUploader(httpClient: httpClient).upload(image: image, settings: settings, clientID: credentials.primary)
    case .amazonS3, .cloudflareR2:
      result = try await S3Uploader(httpClient: httpClient, processRunner: processRunner).upload(
        image: image,
        settings: settings,
        credentials: credentials
      )
    case .googleDrive:
      result = try await GoogleDriveUploader(httpClient: httpClient).upload(image: image, settings: settings, accessToken: credentials.primary)
    case .dropbox:
      result = try await DropboxUploader(httpClient: httpClient).upload(image: image, settings: settings, accessToken: credentials.primary)
    case .s3Compatible:
      result = try await S3CompatibleUploader(processRunner: processRunner).upload(image: image, settings: settings)
    }

    if settings.copyLinkAfterUpload && copyResultToClipboard {
      linkWriter.copy(result.publicURL.absoluteString)
    }

    return result
  }
}
