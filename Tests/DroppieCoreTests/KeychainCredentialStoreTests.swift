import XCTest
@testable import DroppieCore

final class KeychainCredentialStoreTests: XCTestCase {
  func testSaveReadAndDeleteCredential() throws {
    let store = KeychainCredentialStore(service: "com.vyctor.Droppie.Tests.\(UUID().uuidString)")
    let providerID = UUID()

    try store.saveCredential("secret-value", providerID: providerID, name: "primary")
    XCTAssertEqual(try store.readCredential(providerID: providerID, name: "primary"), "secret-value")

    try store.deleteCredential(providerID: providerID, name: "primary")
    XCTAssertNil(try store.readCredential(providerID: providerID, name: "primary"))
  }
}
