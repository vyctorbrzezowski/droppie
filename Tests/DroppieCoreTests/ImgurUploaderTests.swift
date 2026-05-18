import Foundation
import XCTest
@testable import DroppieCore

final class ImgurUploaderTests: XCTestCase {
  func testUploadUsesClientIDAndReturnsImgurLink() async throws {
    let http = MockHTTPClient()
    http.responses = [
      (
        Data(#"{"success":true,"data":{"link":"https://i.imgur.com/abc123.png"}}"#.utf8),
        httpResponse(url: "https://api.imgur.com/3/image")
      )
    ]

    let uploader = ImgurUploader(httpClient: http)
    let result = try await uploader.upload(
      image: ClipboardImage(data: Data([1, 2, 3])),
      settings: ProviderSettings(kind: .imgur),
      clientID: "client-id"
    )

    XCTAssertEqual(result.publicURL.absoluteString, "https://i.imgur.com/abc123.png")
    XCTAssertEqual(http.recordedRequests[0].request.value(forHTTPHeaderField: "Authorization"), "Client-ID client-id")
    XCTAssertTrue(String(data: http.recordedRequests[0].body ?? Data(), encoding: .utf8)?.contains("name=\"image\"") == true)
  }

  func testMissingClientIDFailsBeforeNetwork() async throws {
    let http = MockHTTPClient()
    let uploader = ImgurUploader(httpClient: http)

    do {
      _ = try await uploader.upload(
        image: ClipboardImage(data: Data([1])),
        settings: ProviderSettings(kind: .imgur),
        clientID: nil
      )
      XCTFail("Expected missing credential.")
    } catch let error as UploadError {
      XCTAssertEqual(error, .missingCredential("Imgur Client ID"))
    }
  }

  func testRejectsNonImageBeforeNetwork() async throws {
    let http = MockHTTPClient()
    let uploader = ImgurUploader(httpClient: http)

    do {
      _ = try await uploader.upload(
        image: ClipboardImage(data: Data([1]), contentType: "application/pdf", fileExtension: "pdf"),
        settings: ProviderSettings(kind: .imgur),
        clientID: "client-id"
      )
      XCTFail("Expected invalid configuration.")
    } catch let error as UploadError {
      XCTAssertEqual(error, .invalidConfiguration("Imgur only supports image uploads."))
    }

    XCTAssertTrue(http.recordedRequests.isEmpty)
  }
}
