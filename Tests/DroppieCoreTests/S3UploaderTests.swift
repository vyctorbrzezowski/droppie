import XCTest
@testable import DroppieCore

final class S3UploaderTests: XCTestCase {
  func testR2UploadSignsDirectPUTAndBuildsPublicURL() async throws {
    let http = MockHTTPClient()
    http.responses = [(Data(), httpResponse(status: 200))]
    let date = ISO8601DateFormatter().date(from: "2024-01-02T03:04:05Z")!
    let settings = ProviderSettings(
      kind: .cloudflareR2,
      s3Bucket: "images",
      s3PublicBaseURL: "https://cdn.example.com",
      s3KeyPrefix: "files",
      cloudflareAccountID: "abc123"
    )

    let result = try await S3Uploader(httpClient: http, processRunner: MockProcessRunner(), now: { date }).upload(
      image: ClipboardImage(data: Data("hello".utf8), contentType: "image/png", fileExtension: "png"),
      settings: settings,
      credentials: ProviderCredentials(accessKeyID: "R2_ACCESS", secretAccessKey: "R2_SECRET")
    )

    let request = try XCTUnwrap(http.recordedRequests.first?.request)
    XCTAssertEqual(request.url?.host, "abc123.r2.cloudflarestorage.com")
    XCTAssertEqual(request.value(forHTTPHeaderField: "x-amz-date"), "20240102T030405Z")
    XCTAssertEqual(request.value(forHTTPHeaderField: "x-amz-content-sha256"), "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    XCTAssertTrue(request.value(forHTTPHeaderField: "authorization")?.contains("Credential=R2_ACCESS/20240102/auto/s3/aws4_request") == true)
    XCTAssertEqual(result.provider, .cloudflareR2)
    XCTAssertTrue(result.publicURL.absoluteString.hasPrefix("https://cdn.example.com/files/droppie-"))
  }

  func testAmazonS3RequiresAccessKeysForDirectMode() async throws {
    let settings = ProviderSettings(
      kind: .amazonS3,
      s3Bucket: "images",
      s3Region: "us-east-1",
      s3PublicBaseURL: "https://images.example.com"
    )

    do {
      _ = try await S3Uploader(httpClient: MockHTTPClient(), processRunner: MockProcessRunner()).upload(
        image: ClipboardImage(data: Data("hello".utf8)),
        settings: settings,
        credentials: ProviderCredentials()
      )
      XCTFail("Expected missing credential")
    } catch let error as UploadError {
      XCTAssertEqual(error, .missingCredential("Access Key ID"))
    }
  }
}
