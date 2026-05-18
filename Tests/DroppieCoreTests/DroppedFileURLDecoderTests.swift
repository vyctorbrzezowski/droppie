import Foundation
import XCTest
@testable import DroppieCore

final class DroppedFileURLDecoderTests: XCTestCase {
  func testDecodesFileURLFromNSURL() {
    let url = URL(fileURLWithPath: "/tmp/droppie.png")

    XCTAssertEqual(DroppedFileURLDecoder.fileURL(from: url as NSURL), url)
  }

  func testDecodesFileURLFromDataRepresentation() {
    let url = URL(fileURLWithPath: "/tmp/droppie.png")
    let data = url.dataRepresentation

    XCTAssertEqual(DroppedFileURLDecoder.fileURL(from: data as NSData), url)
  }

  func testRejectsRemoteURLString() {
    XCTAssertNil(DroppedFileURLDecoder.fileURL(from: "https://example.com/image.png" as NSString))
  }
}
