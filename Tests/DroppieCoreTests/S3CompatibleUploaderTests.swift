import Foundation
import XCTest
@testable import DroppieCore

final class S3CompatibleUploaderTests: XCTestCase {
  func testUploadUsesAWSCLIAndBuildsPublicURL() async throws {
    let runner = MockProcessRunner()
    let settings = ProviderSettings(
      kind: .s3Compatible,
      s3Bucket: "my-bucket",
      s3Region: "us-east-1",
      s3EndpointURL: "https://r2.example.com",
      s3PublicBaseURL: "https://cdn.example.com",
      s3KeyPrefix: "screens",
      s3Profile: "personal"
    )

    let result = try await S3CompatibleUploader(processRunner: runner).upload(
      image: ClipboardImage(data: Data([1, 2, 3])),
      settings: settings
    )

    XCTAssertEqual(runner.executable, "/usr/bin/env")
    XCTAssertEqual(runner.arguments.first, "aws")
    XCTAssertTrue(runner.arguments.contains("s3://my-bucket/screens/\(result.publicURL.lastPathComponent)"))
    XCTAssertTrue(runner.arguments.contains("--profile"))
    XCTAssertTrue(runner.arguments.contains("personal"))
    XCTAssertEqual(result.publicURL.host, "cdn.example.com")
    XCTAssertTrue(result.publicURL.path.contains("/screens/droppie-"))
  }

  func testUploadRequiresPublicBaseURL() async throws {
    let runner = MockProcessRunner()
    let settings = ProviderSettings(kind: .s3Compatible, s3Bucket: "bucket")

    do {
      _ = try await S3CompatibleUploader(processRunner: runner).upload(
        image: ClipboardImage(data: Data([1])),
        settings: settings
      )
      XCTFail("Expected invalid configuration.")
    } catch let error as UploadError {
      XCTAssertEqual(error, .invalidConfiguration("Public base URL is required for S3/R2."))
    }
  }

  func testCommandFailureReturnsUsefulMessage() async throws {
    let runner = MockProcessRunner()
    runner.result = ProcessResult(exitCode: 1, stdout: "", stderr: "AccessDenied")
    let settings = ProviderSettings(
      kind: .s3Compatible,
      s3Bucket: "bucket",
      s3PublicBaseURL: "https://cdn.example.com"
    )

    do {
      _ = try await S3CompatibleUploader(processRunner: runner).upload(
        image: ClipboardImage(data: Data([1])),
        settings: settings
      )
      XCTFail("Expected command failure.")
    } catch let error as UploadError {
      XCTAssertEqual(error, .commandFailed("AccessDenied"))
    }
  }
}
