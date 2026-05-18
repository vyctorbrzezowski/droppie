import XCTest
@testable import DroppieCore

final class GoogleDriveUploaderTests: XCTestCase {
  func testUploadCreatesPublicDriveFile() async throws {
    let http = MockHTTPClient()
    http.responses = [
      (Data(#"{"id":"file-1","webViewLink":"https://drive.google.com/file/d/file-1/view"}"#.utf8), httpResponse(status: 200)),
      (Data(#"{"id":"permission-1"}"#.utf8), httpResponse(status: 200)),
      (Data(#"{"id":"file-1","webViewLink":"https://drive.google.com/file/d/file-1/view","webContentLink":"https://drive.google.com/uc?id=file-1"}"#.utf8), httpResponse(status: 200))
    ]
    let settings = ProviderSettings(kind: .googleDrive, googleDriveFolderID: "folder-1")

    let result = try await GoogleDriveUploader(httpClient: http).upload(
      image: ClipboardImage(data: Data("hello".utf8), contentType: "image/png", fileExtension: "png"),
      settings: settings,
      accessToken: "drive-token"
    )

    XCTAssertEqual(http.recordedRequests.count, 3)
    XCTAssertEqual(http.recordedRequests[0].request.url?.path, "/upload/drive/v3/files")
    XCTAssertEqual(http.recordedRequests[0].request.value(forHTTPHeaderField: "Authorization"), "Bearer drive-token")
    XCTAssertTrue(String(data: try XCTUnwrap(http.recordedRequests[0].body), encoding: .utf8)?.contains("\"parents\":[\"folder-1\"]") == true)
    XCTAssertEqual(http.recordedRequests[1].request.url?.path, "/drive/v3/files/file-1/permissions")
    XCTAssertEqual(result.provider, .googleDrive)
    XCTAssertEqual(result.publicURL.absoluteString, "https://drive.google.com/file/d/file-1/view")
  }
}
