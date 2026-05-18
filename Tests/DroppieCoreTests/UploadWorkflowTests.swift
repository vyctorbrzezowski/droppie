import Foundation
import XCTest
@testable import DroppieCore

final class UploadWorkflowTests: XCTestCase {
  func testReadClipboardImageReturnsReaderImage() throws {
    let image = ClipboardImage(data: Data([9, 8, 7]), contentType: "image/png", fileExtension: "png")
    let workflow = UploadWorkflow(
      imageReader: FixedImageReader(image: image),
      linkWriter: RecordingLinkWriter()
    )

    XCTAssertEqual(try workflow.readClipboardImage(), image)
  }

  func testCopiesGeneratedLinkWhenEnabled() async throws {
    let http = MockHTTPClient()
    http.responses = [
      (
        Data("""
        {
          "slug": "droppie-test",
          "siteUrl": "https://droppie-test.here.now/",
          "upload": {
            "versionId": "v1",
            "uploads": [
              {
                "path": "image.png",
                "method": "PUT",
                "url": "https://upload.example.com/file",
                "headers": { "Content-Type": "image/png" }
              }
            ],
            "finalizeUrl": "https://here.now/api/v1/publish/droppie-test/finalize"
          }
        }
        """.utf8),
        httpResponse(url: "https://here.now/api/v1/publish")
      ),
      (Data(), httpResponse(url: "https://upload.example.com/file")),
      (Data(#"{"success":true}"#.utf8), httpResponse(url: "https://here.now/api/v1/publish/droppie-test/finalize"))
    ]
    let writer = RecordingLinkWriter()
    let workflow = UploadWorkflow(
      imageReader: FixedImageReader(image: ClipboardImage(data: Data([1, 2, 3]))),
      linkWriter: writer,
      httpClient: http
    )

    let result = try await workflow.uploadClipboard(
      settings: ProviderSettings(kind: .hereNow, copyLinkAfterUpload: true),
      credential: "secret"
    )

    XCTAssertEqual(writer.values, [result.publicURL.absoluteString])
  }

  func testDoesNotCopyGeneratedLinkWhenDisabled() async throws {
    let http = MockHTTPClient()
    http.responses = [
      (
        Data("""
        {
          "slug": "droppie-test",
          "siteUrl": "https://droppie-test.here.now/",
          "upload": {
            "versionId": "v1",
            "uploads": [
              {
                "path": "image.png",
                "method": "PUT",
                "url": "https://upload.example.com/file",
                "headers": { "Content-Type": "image/png" }
              }
            ],
            "finalizeUrl": "https://here.now/api/v1/publish/droppie-test/finalize"
          }
        }
        """.utf8),
        httpResponse(url: "https://here.now/api/v1/publish")
      ),
      (Data(), httpResponse(url: "https://upload.example.com/file")),
      (Data(#"{"success":true}"#.utf8), httpResponse(url: "https://here.now/api/v1/publish/droppie-test/finalize"))
    ]
    let writer = RecordingLinkWriter()
    let workflow = UploadWorkflow(
      imageReader: FixedImageReader(image: ClipboardImage(data: Data([1, 2, 3]))),
      linkWriter: writer,
      httpClient: http
    )

    _ = try await workflow.uploadClipboard(
      settings: ProviderSettings(kind: .hereNow, copyLinkAfterUpload: false),
      credential: "secret"
    )

    XCTAssertTrue(writer.values.isEmpty)
  }

  func testUploadFileCanSkipClipboardCopyForBatchMode() async throws {
    let http = MockHTTPClient()
    http.responses = [
      (
        Data("""
        {
          "slug": "droppie-test",
          "siteUrl": "https://droppie-test.here.now/",
          "upload": {
            "versionId": "v1",
            "uploads": [
              {
                "path": "image.png",
                "method": "PUT",
                "url": "https://upload.example.com/file",
                "headers": { "Content-Type": "image/png" }
              }
            ],
            "finalizeUrl": "https://here.now/api/v1/publish/droppie-test/finalize"
          }
        }
        """.utf8),
        httpResponse(url: "https://here.now/api/v1/publish")
      ),
      (Data(), httpResponse(url: "https://upload.example.com/file")),
      (Data(#"{"success":true}"#.utf8), httpResponse(url: "https://here.now/api/v1/publish/droppie-test/finalize"))
    ]
    let writer = RecordingLinkWriter()
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("droppie-\(UUID().uuidString)")
      .appendingPathExtension("png")
    try samplePNGData().write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let workflow = UploadWorkflow(
      imageReader: FixedImageReader(image: ClipboardImage(data: Data([1, 2, 3]))),
      linkWriter: writer,
      httpClient: http
    )

    _ = try await workflow.uploadFile(
      at: url,
      settings: ProviderSettings(kind: .hereNow, copyLinkAfterUpload: true),
      credential: "secret",
      copyResultToClipboard: false
    )

    XCTAssertTrue(writer.values.isEmpty)
  }
}
