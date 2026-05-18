import Foundation
import Security

public protocol CredentialStore: Sendable {
  func readCredential(providerID: UUID, name: String) throws -> String?
  func saveCredential(_ value: String, providerID: UUID, name: String) throws
  func deleteCredential(providerID: UUID, name: String) throws
}

public final class KeychainCredentialStore: CredentialStore {
  private let service: String

  public init(service: String = "com.vyctor.Droppie") {
    self.service = service
  }

  public func readCredential(providerID: UUID, name: String) throws -> String? {
    var query = baseQuery(providerID: providerID, name: name)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }

    guard status == errSecSuccess else {
      throw KeychainError(status: status)
    }

    guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
      return nil
    }

    return value
  }

  public func saveCredential(_ value: String, providerID: UUID, name: String) throws {
    if value.trimmedDroppie.isEmpty {
      try deleteCredential(providerID: providerID, name: name)
      return
    }

    let data = Data(value.utf8)
    let query = baseQuery(providerID: providerID, name: name)
    let attributes = [kSecValueData as String: data]

    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess {
      return
    }

    if updateStatus != errSecItemNotFound {
      throw KeychainError(status: updateStatus)
    }

    var addQuery = query
    addQuery[kSecValueData as String] = data
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw KeychainError(status: addStatus)
    }
  }

  public func deleteCredential(providerID: UUID, name: String) throws {
    let status = SecItemDelete(baseQuery(providerID: providerID, name: name) as CFDictionary)
    if status == errSecItemNotFound || status == errSecSuccess {
      return
    }

    throw KeychainError(status: status)
  }

  private func baseQuery(providerID: UUID, name: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "\(providerID.uuidString):\(name)"
    ]
  }
}

public struct KeychainError: LocalizedError, Equatable {
  public var status: OSStatus

  public var errorDescription: String? {
    "Keychain error \(status)."
  }
}
