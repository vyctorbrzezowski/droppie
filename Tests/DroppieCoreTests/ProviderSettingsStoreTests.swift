import Foundation
import XCTest
@testable import DroppieCore

final class ProviderSettingsStoreTests: XCTestCase {
  func testRoundTripSettingsAndSelectedProvider() throws {
    let suiteName = "DroppieTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = ProviderSettingsStore(defaults: defaults)
    let provider = ProviderSettings(kind: .hereNow, name: "Permanent")

    try store.save(settings: [provider], selectedID: provider.id)
    let loaded = store.load()

    XCTAssertEqual(loaded.0, [provider])
    XCTAssertEqual(loaded.1, provider.id)
  }

}
