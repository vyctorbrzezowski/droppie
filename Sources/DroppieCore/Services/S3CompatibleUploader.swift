import Foundation

public final class S3CompatibleUploader: Sendable {
  private let processRunner: ProcessRunning
  private let fileNameFactory: FileNameFactory

  public init(processRunner: ProcessRunning, fileNameFactory: FileNameFactory = FileNameFactory()) {
    self.processRunner = processRunner
    self.fileNameFactory = fileNameFactory
  }

  public func upload(image: ClipboardImage, settings: ProviderSettings) async throws -> UploadResult {
    let bucket = settings.s3Bucket.trimmedDroppie
    guard !bucket.isEmpty else {
      throw UploadError.invalidConfiguration("S3 bucket is required.")
    }

    guard let publicBaseURL = URL(string: settings.s3PublicBaseURL.trimmedDroppie), publicBaseURL.scheme != nil else {
      throw UploadError.invalidConfiguration("Public base URL is required for S3/R2.")
    }

    let prefix = settings.s3KeyPrefix.trimmedDroppie.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let fileName = fileNameFactory.makeFileName(extension: image.fileExtension)
    let objectKey = prefix.isEmpty ? fileName : "\(prefix)/\(fileName)"

    let temporaryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("Droppie-\(UUID().uuidString)")
      .appendingPathExtension(image.fileExtension)

    try image.data.write(to: temporaryURL, options: .atomic)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    var arguments = ["s3", "cp", temporaryURL.path, "s3://\(bucket)/\(objectKey)", "--content-type", image.contentType]

    if let profile = settings.s3Profile.nilIfBlankDroppie {
      arguments += ["--profile", profile]
    }

    if let region = settings.s3Region.nilIfBlankDroppie {
      arguments += ["--region", region]
    }

    if let endpoint = settings.s3EndpointURL.nilIfBlankDroppie {
      arguments += ["--endpoint-url", endpoint]
    }

    let result = try await processRunner.run(executable: "/usr/bin/env", arguments: ["aws"] + arguments)
    guard result.exitCode == 0 else {
      let message = result.stderr.nilIfBlankDroppie ?? result.stdout.nilIfBlankDroppie ?? "aws exited with \(result.exitCode)."
      throw UploadError.commandFailed(message)
    }

    return UploadResult(
      provider: settings.kind,
      publicURL: publicBaseURL.appendingPathComponentPreservingDirectory(objectKey),
      bytes: image.data.count
    )
  }
}
