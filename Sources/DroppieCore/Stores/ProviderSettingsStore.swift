import Foundation

public final class ProviderSettingsStore {
  private let defaults: UserDefaults
  private let settingsKey = "providerSettings"
  private let selectedIDKey = "selectedProviderID"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func load() -> ([ProviderSettings], UUID?) {
    let settings: [ProviderSettings]
    if let data = defaults.data(forKey: settingsKey),
       let decoded = try? JSONDecoder().decode([ProviderSettings].self, from: data) {
      settings = decoded
    } else {
      settings = []
    }

    let selectedID = defaults.string(forKey: selectedIDKey).flatMap(UUID.init(uuidString:))
    return (settings, selectedID)
  }

  public func save(settings: [ProviderSettings], selectedID: UUID?) throws {
    let data = try JSONEncoder().encode(settings)
    defaults.set(data, forKey: settingsKey)
    if let selectedID {
      defaults.set(selectedID.uuidString, forKey: selectedIDKey)
    } else {
      defaults.removeObject(forKey: selectedIDKey)
    }
  }
}
