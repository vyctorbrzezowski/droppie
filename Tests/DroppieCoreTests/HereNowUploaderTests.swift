import Foundation
import XCTest
@testable import DroppieCore

final class HereNowUploaderTests: XCTestCase {
  func testUploadCreatesPublishesAndFinalizesWithAuthenticatedDirectImageURL() async throws {
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

    let uploader = HereNowUploader(httpClient: http)
    let image = ClipboardImage(data: Data([1, 2, 3]))
    let result = try await uploader.upload(
      image: image,
      settings: ProviderSettings(kind: .hereNow),
      apiKey: "secret"
    )

    XCTAssertEqual(result.provider, .hereNow)
    XCTAssertTrue(result.publicURL.absoluteString.hasPrefix("https://droppie-test.here.now/droppie-"))
    XCTAssertEqual(http.recordedRequests.count, 3)
    XCTAssertEqual(http.recordedRequests[0].request.url?.absoluteString, "https://here.now/api/v1/publish")
    XCTAssertEqual(http.recordedRequests[0].request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
    XCTAssertEqual(http.recordedRequests[1].request.httpMethod, "PUT")
    XCTAssertEqual(http.recordedRequests[2].request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
  }
}
