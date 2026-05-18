import XCTest
@testable import DroppieCore

final class DropboxUploaderTests: XCTestCase {
  func testUploadCreatesSharedDropboxLink() async throws {
    let http = MockHTTPClient()
    http.responses = [
      (Data(#"{"path_display":"/Droppie/droppie.png"}"#.utf8), httpResponse(url: "https://content.dropboxapi.com", status: 200)),
      (Data(#"{"url":"https://www.dropbox.com/s/example/droppie.png?dl=0"}"#.utf8), httpResponse(url: "https://api.dropboxapi.com", status: 200))
    ]
    let settings = ProviderSettings(kind: .dropbox, dropboxPathPrefix: "/Droppie")

    let result = try await DropboxUploader(httpClient: http).upload(
      image: ClipboardImage(data: Data("hello".utf8), contentType: "image/png", fileExtension: "png"),
      settings: settings,
      accessToken: "dropbox-token"
    )

    XCTAssertEqual(http.recordedRequests.count, 2)
    XCTAssertEqual(http.recordedRequests[0].request.url?.host, "content.dropboxapi.com")
    XCTAssertEqual(http.recordedRequests[0].request.url?.path, "/2/files/upload")
    XCTAssertEqual(http.recordedRequests[0].request.value(forHTTPHeaderField: "Authorization"), "Bearer dropbox-token")
    XCTAssertTrue(http.recordedRequests[0].request.value(forHTTPHeaderField: "Dropbox-API-Arg")?.contains("Droppie") == true)
    XCTAssertEqual(http.recordedRequests[1].request.url?.path, "/2/sharing/create_shared_link_with_settings")
    XCTAssertEqual(result.provider, .dropbox)
    XCTAssertEqual(result.publicURL.absoluteString, "https://www.dropbox.com/s/example/droppie.png?dl=0")
  }
}
