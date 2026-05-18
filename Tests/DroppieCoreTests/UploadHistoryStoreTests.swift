import Foundation
import XCTest
@testable import DroppieCore

final class UploadHistoryStoreTests: XCTestCase {
  func testRoundTripHistoryWithLimit() throws {
    let suiteName = "DroppieHistoryTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = UploadHistoryStore(defaults: defaults, limit: 2)
    let entries = [
      UploadHistoryEntry(publicURL: URL(string: "https://a.example/1.png")!, provider: .hereNow, bytes: 1, createdAt: Date()),
      UploadHistoryEntry(publicURL: URL(string: "https://a.example/2.png")!, provider: .imgur, bytes: 2, createdAt: Date()),
      UploadHistoryEntry(publicURL: URL(string: "https://a.example/3.png")!, provider: .s3Compatible, bytes: 3, createdAt: Date())
    ]

    try store.save(entries)

    XCTAssertEqual(store.load(), Array(entries.prefix(2)))
  }

  func testRoundTripHistoryPreservesDisplayMetadata() throws {
    let suiteName = "DroppieHistoryTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = UploadHistoryStore(defaults: defaults)
    let thumbnail = Data([0x01, 0x02, 0x03])
    let entry = UploadHistoryEntry(
      publicURL: URL(string: "https://a.example/1.png")!,
      provider: .hereNow,
      bytes: 1,
      createdAt: Date(),
      thumbnailData: thumbnail,
      displayName: "clip.mov",
      contentType: "video/quicktime"
    )

    try store.save([entry])

    let loaded = store.load().first
    XCTAssertEqual(loaded?.thumbnailData, thumbnail)
    XCTAssertEqual(loaded?.displayName, "clip.mov")
    XCTAssertEqual(loaded?.contentType, "video/quicktime")
  }

  func testClearHistory() throws {
    let suiteName = "DroppieHistoryTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = UploadHistoryStore(defaults: defaults)
    try store.save([
      UploadHistoryEntry(publicURL: URL(string: "https://a.example/1.png")!, provider: .hereNow, bytes: 1, createdAt: Date())
    ])

    store.clear()

    XCTAssertEqual(store.load(), [])
  }
}
