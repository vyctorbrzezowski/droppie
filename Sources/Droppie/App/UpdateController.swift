import Foundation
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject {
  @Published private(set) var isUpdateAvailable = false

  private var updaterController: SPUStandardUpdaterController?
  private var initialProbeTask: Task<Void, Never>?

  var canCheckForUpdates: Bool {
    updaterController?.updater.canCheckForUpdates ?? false
  }

  override init() {
    super.init()

    guard Self.hasSparkleConfiguration else {
      return
    }

    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
    scheduleInitialProbe()
  }

  deinit {
    initialProbeTask?.cancel()
  }

  func checkForUpdates() {
    guard let updaterController else {
      return
    }

    updaterController.checkForUpdates(nil)
  }

  private func scheduleInitialProbe() {
    initialProbeTask?.cancel()
    initialProbeTask = Task { [weak self] in
      for _ in 0..<5 {
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else {
          return
        }

        let didStart = await MainActor.run {
          self?.probeForUpdate() ?? false
        }
        if didStart {
          return
        }
      }
    }
  }

  private func probeForUpdate() -> Bool {
    guard let updater = updaterController?.updater,
          updater.canCheckForUpdates else {
      return false
    }

    updater.checkForUpdateInformation()
    return true
  }

  private static var hasSparkleConfiguration: Bool {
    guard let info = Bundle.main.infoDictionary,
          let feedURLString = info["SUFeedURL"] as? String,
          let feedURL = URL(string: feedURLString.trimmedForUpdate),
          ["http", "https"].contains(feedURL.scheme?.lowercased()),
          let publicKey = info["SUPublicEDKey"] as? String,
          !publicKey.trimmedForUpdate.isEmpty else {
      return false
    }

    return true
  }
}

extension UpdateController: SPUUpdaterDelegate {
  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    isUpdateAvailable = true
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
    isUpdateAvailable = false
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
    isUpdateAvailable = false
  }

  func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
    isUpdateAvailable = false
  }
}

private extension String {
  var trimmedForUpdate: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
