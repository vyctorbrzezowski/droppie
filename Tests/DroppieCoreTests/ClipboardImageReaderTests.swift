import AppKit
import XCTest
@testable import DroppieCore

final class ClipboardImageReaderTests: XCTestCase {
  func testReadsPNGFromPasteboard() throws {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("DroppieTests-\(UUID().uuidString)"))
    pasteboard.clearContents()
    let png = samplePNGData()
    pasteboard.setData(png, forType: .png)

    let image = try PasteboardClipboardImageReader(pasteboard: pasteboard).readImage()

    XCTAssertEqual(image.contentType, "image/png")
    XCTAssertEqual(image.fileExtension, "png")
    XCTAssertEqual(image.data, png)
  }

  func testReadsPNGFromFileURL() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("droppie-\(UUID().uuidString)")
      .appendingPathExtension("png")
    let png = samplePNGData()
    try png.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let image = try ImageFileReader().readImage(at: url)

    XCTAssertEqual(image.contentType, "image/png")
    XCTAssertEqual(image.fileExtension, "png")
    XCTAssertEqual(image.data, png)
    XCTAssertTrue(image.isImage)
  }

  func testReadsNonImageFileURL() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("droppie-\(UUID().uuidString)")
      .appendingPathExtension("txt")
    let data = Data("hello".utf8)
    try data.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let file = try ImageFileReader().readImage(at: url)

    XCTAssertEqual(file.contentType, "text/plain")
    XCTAssertEqual(file.fileExtension, "txt")
    XCTAssertEqual(file.data, data)
    XCTAssertFalse(file.isImage)
  }
}
