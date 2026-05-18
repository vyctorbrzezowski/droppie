import AppKit
import Combine
import Foundation
import ImageIO
import DroppieCore
import Security
import UniformTypeIdentifiers

private struct CompletedUpload: Sendable {
  var result: UploadResult
  var thumbnailData: Data?
  var displayName: String?
  var contentType: String

  var displayItem: UploadDisplayItem {
    UploadDisplayItem(
      result: result,
      thumbnailData: thumbnailData,
      displayName: displayName,
      contentType: contentType
    )
  }
}

private struct FailedUpload: Error, Sendable {
  var displayName: String
  var message: String
}

struct UploadDisplayItem: Identifiable, Equatable {
  var result: UploadResult
  var thumbnailData: Data?
  var displayName: String?
  var contentType: String

  var id: URL {
    result.publicURL
  }

  var publicURL: URL {
    result.publicURL
  }

  var openURL: URL {
    if result.provider == .hereNow, isVideo {
      return result.publicURL.deletingLastPathComponent()
    }

    return result.publicURL
  }

  var isVideo: Bool {
    contentType.lowercased().hasPrefix("video/")
  }
}

@MainActor
final class DroppieModel: ObservableObject {
  @Published var providers: [ProviderSettings] = []
  @Published var selectedProviderID: UUID?
  @Published var editingProvider: ProviderSettings
  @Published var credentialDraft = ""
  @Published var accessKeyIDDraft = ""
  @Published var secretAccessKeyDraft = ""
  @Published var sessionTokenDraft = ""
  @Published var status: UploadStatus = .idle
  @Published var lastResult: UploadResult?
  @Published var lastResults: [UploadResult] = []
  @Published var lastUploadItems: [UploadDisplayItem] = []
  @Published var lastError: String?
  @Published var copyConfirmation = false
  @Published var batchCompletedCount = 0
  @Published var batchTotalCount = 0
  @Published var lastBatchSkippedCount = 0
  @Published var lastBatchFailedCount = 0
  @Published var history: [UploadHistoryEntry] = []
  @Published var lastPreviewImage: NSImage?
  @Published var isDropTargeted = false

  private let settingsStore: ProviderSettingsStore
  private let historyStore: UploadHistoryStore
  private let credentialStore: CredentialStore
  private let workflow: UploadWorkflow
  private var copyFeedbackTask: Task<Void, Never>?
  private var errorFeedbackTask: Task<Void, Never>?
  private let linkWriter: ClipboardLinkWriting
  private let maxDroppedImages = 15
  private let maxParallelUploads = 4

  init(
    settingsStore: ProviderSettingsStore = ProviderSettingsStore(),
    historyStore: UploadHistoryStore = UploadHistoryStore(),
    credentialStore: CredentialStore = KeychainCredentialStore(),
    workflow: UploadWorkflow = UploadWorkflow(
      imageReader: PasteboardClipboardImageReader(),
      linkWriter: PasteboardLinkWriter()
    ),
    linkWriter: ClipboardLinkWriting = PasteboardLinkWriter()
  ) {
    self.settingsStore = settingsStore
    self.historyStore = historyStore
    self.credentialStore = credentialStore
    self.workflow = workflow
    self.linkWriter = linkWriter

    let loaded = settingsStore.load()
    let loadedHistory = historyStore.load()
    var loadedProviders = loaded.0
    var loadedSelectedID = loaded.1 ?? loaded.0.first?.id

    if loadedProviders.isEmpty, let hereNowKey = Self.readHereNowCredentialsFile() {
      let provider = ProviderSettings(kind: .hereNow)
      loadedProviders = [provider]
      loadedSelectedID = provider.id
      try? credentialStore.saveCredential(hereNowKey, providerID: provider.id, name: "primary")
      try? settingsStore.save(settings: loadedProviders, selectedID: provider.id)
    }

    self.providers = loadedProviders
    self.selectedProviderID = loadedSelectedID
    self.editingProvider = loadedProviders.first ?? ProviderSettings(kind: .hereNow)
    self.history = loadedHistory
    self.loadCredentialDrafts(for: self.editingProvider)
  }

  var selectedProvider: ProviderSettings? {
    guard let selectedProviderID else {
      return providers.first
    }
    return providers.first { $0.id == selectedProviderID }
  }

  var hasConfiguredProvider: Bool {
    selectedProvider != nil
  }

  var isUploading: Bool {
    status == .uploading
  }

  func selectProvider(_ provider: ProviderSettings) {
    selectedProviderID = provider.id
    editingProvider = provider
    loadCredentialDrafts(for: provider)
    persist()
  }

  func startNewProvider(kind: UploadProviderKind) {
    editingProvider = ProviderSettings(kind: kind)
    credentialDraft = kind == .hereNow ? (Self.readHereNowCredentialsFile() ?? "") : ""
    accessKeyIDDraft = ""
    secretAccessKeyDraft = ""
    sessionTokenDraft = ""
  }

  func saveEditingProvider() {
    var provider = editingProvider
    provider.name = provider.name.trimmedDroppie.isEmpty ? provider.kind.title : provider.name.trimmedDroppie

    if let index = providers.firstIndex(where: { $0.id == provider.id }) {
      providers[index] = provider
    } else {
      providers.append(provider)
    }

    selectedProviderID = provider.id
    editingProvider = provider

    saveCredentialDrafts(for: provider)

    persist()
    lastError = nil
  }

  func deleteSelectedProvider() {
    guard let selectedProviderID else {
      return
    }

    try? credentialStore.deleteCredential(providerID: selectedProviderID, name: "primary")
    try? credentialStore.deleteCredential(providerID: selectedProviderID, name: "accessKeyID")
    try? credentialStore.deleteCredential(providerID: selectedProviderID, name: "secretAccessKey")
    try? credentialStore.deleteCredential(providerID: selectedProviderID, name: "sessionToken")
    providers.removeAll { $0.id == selectedProviderID }
    self.selectedProviderID = providers.first?.id
    editingProvider = providers.first ?? ProviderSettings(kind: .hereNow)
    loadCredentialDrafts(for: editingProvider)
    persist()
  }

  func uploadClipboard() {
    guard let provider = selectedProvider else {
      presentError("Add a provider first.")
      return
    }

    prepareUpload(totalCount: 1)

    Task {
      do {
        let image = try workflow.readClipboardImage()
        let thumbnailData = Self.thumbnailData(from: image)
        let credentials = try credentials(for: provider)
        let result = try await workflow.uploadImage(image, settings: provider, credentials: credentials)

        await MainActor.run {
          self.lastPreviewImage = Self.previewImage(from: thumbnailData)
          self.lastResult = result
          self.lastResults = [result]
          self.lastUploadItems = [
            CompletedUpload(
              result: result,
              thumbnailData: thumbnailData,
              displayName: nil,
              contentType: image.contentType
            ).displayItem
          ]
          self.batchCompletedCount = 1
          self.status = .finished
          self.recordHistory([
            CompletedUpload(
              result: result,
              thumbnailData: thumbnailData,
              displayName: nil,
              contentType: image.contentType
            )
          ])
          if provider.copyLinkAfterUpload {
            self.showCopyConfirmation(duration: .seconds(20))
          }
        }
      } catch {
        await MainActor.run {
          self.presentError(error.localizedDescription, autoDismiss: Self.isTransientError(error))
          self.status = .failed
        }
      }
    }
  }

  func uploadDroppedFile(_ url: URL) {
    uploadDroppedFiles([url])
  }

  func chooseFilesForUpload() {
    guard !isUploading else {
      return
    }

    NSApp.activate(ignoringOtherApps: true)

    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = true
    panel.prompt = "Upload"
    panel.level = .floating

    panel.begin { [weak self] response in
      guard response == .OK else {
        return
      }

      Task { @MainActor in
        self?.uploadDroppedFiles(panel.urls)
      }
    }
  }

  func uploadDroppedFiles(_ urls: [URL]) {
    let selectedURLs = Array(urls.prefix(maxDroppedImages))
    lastBatchSkippedCount = max(0, urls.count - selectedURLs.count)

    guard !selectedURLs.isEmpty else {
      presentError("No supported file found.", autoDismiss: true)
      return
    }

    uploadBatch(selectedURLs)
  }

  private func uploadBatch(_ urls: [URL]) {
    guard let provider = selectedProvider else {
      presentError("Add a provider first.")
      return
    }

    status = .uploading
    prepareUpload(totalCount: urls.count)

    Task {
      do {
        let credentials = try credentials(for: provider)
        let workflow = self.workflow
        var indexedUploads = Array<CompletedUpload?>(repeating: nil, count: urls.count)
        var failedUploads: [FailedUpload] = []
        var nextIndex = 0

        let uploads = await withTaskGroup(of: (Int, Result<CompletedUpload, FailedUpload>).self) { group in
          func enqueueNext() {
            guard nextIndex < urls.count else {
              return
            }

            let index = nextIndex
            let url = urls[index]
            nextIndex += 1

            group.addTask {
              do {
                let image = try workflow.readFile(at: url)
                let result = try await workflow.uploadImage(
                  image,
                  settings: provider,
                  credentials: credentials,
                  copyResultToClipboard: false
                )
                return (
                  index,
                  .success(CompletedUpload(
                    result: result,
                    thumbnailData: Self.thumbnailData(from: image),
                    displayName: url.lastPathComponent.nilIfBlankDroppie,
                    contentType: image.contentType
                  ))
                )
              } catch {
                return (
                  index,
                  .failure(FailedUpload(
                    displayName: url.lastPathComponent.nilIfBlankDroppie ?? "File \(index + 1)",
                    message: error.localizedDescription
                  ))
                )
              }
            }
          }

          for _ in 0..<min(maxParallelUploads, urls.count) {
            enqueueNext()
          }

          for await (index, outcome) in group {
            switch outcome {
            case .success(let upload):
              indexedUploads[index] = upload
              await MainActor.run {
                self.batchCompletedCount += 1
                self.lastResults = indexedUploads.compactMap { $0?.result }
                self.lastUploadItems = indexedUploads.compactMap { $0?.displayItem }
                self.lastResult = upload.result
                self.lastPreviewImage = Self.previewImage(from: upload.thumbnailData)
              }
            case .failure(let failed):
              failedUploads.append(failed)
              await MainActor.run {
                self.batchCompletedCount += 1
                self.lastBatchFailedCount = failedUploads.count
              }
            }
            enqueueNext()
          }

          return indexedUploads.compactMap { $0 }
        }

        await MainActor.run {
          let results = uploads.map(\.result)
          let failedCount = failedUploads.count
          self.lastResults = results
          self.lastUploadItems = uploads.map(\.displayItem)
          self.lastResult = results.last
          self.lastBatchFailedCount = failedCount
          self.status = results.isEmpty ? .failed : .finished
          self.recordHistory(uploads)

          if provider.copyLinkAfterUpload || results.count > 1 {
            self.copyLinks(results, feedbackDuration: results.count == 1 ? .seconds(20) : .seconds(1.4))
          }

          if failedCount > 0 {
            self.presentError(Self.batchFailureMessage(successCount: results.count, failedCount: failedCount))
          }
        }
      } catch {
        await MainActor.run {
          self.presentError(error.localizedDescription)
          self.status = .failed
        }
      }
    }
  }

  private func prepareUpload(totalCount: Int) {
    status = .uploading
    lastError = nil
    errorFeedbackTask?.cancel()
    copyConfirmation = false
    lastBatchSkippedCount = 0
    lastBatchFailedCount = 0
    isDropTargeted = false
    lastResults = []
    lastUploadItems = []
    lastResult = nil
    lastPreviewImage = nil
    batchCompletedCount = 0
    batchTotalCount = totalCount
  }

  func copyLastLink() {
    guard let link = lastResult?.publicURL.absoluteString else {
      return
    }
    linkWriter.copy(link)
    showCopyConfirmation()
  }

  func copyAllLinks() {
    copyLinks(lastResults)
  }

  var canRetryLastError: Bool {
    guard let lastError else {
      return false
    }

    return lastError != UploadError.missingImage.localizedDescription
      && lastError != "No supported file found."
  }

  func dismissLastError() {
    errorFeedbackTask?.cancel()
    lastError = nil
    if status == .failed {
      status = .idle
      batchCompletedCount = 0
      batchTotalCount = 0
      lastBatchSkippedCount = 0
      lastBatchFailedCount = 0
      isDropTargeted = false
    }
  }

  func clearFinishedUploadSession() {
    guard status == .finished else {
      return
    }

    copyFeedbackTask?.cancel()
    errorFeedbackTask?.cancel()
    status = .idle
    lastResult = nil
    lastResults = []
    lastUploadItems = []
    lastPreviewImage = nil
    lastError = nil
    copyConfirmation = false
    batchCompletedCount = 0
    batchTotalCount = 0
    lastBatchSkippedCount = 0
    lastBatchFailedCount = 0
  }

  func copyLink(_ url: URL, showsFeedback: Bool = true) {
    linkWriter.copy(url.absoluteString)
    if showsFeedback {
      showCopyConfirmation()
    }
  }

  func openLastLinks() {
    let urls: [URL]
    if !lastUploadItems.isEmpty {
      urls = lastUploadItems.map(\.openURL)
    } else {
      urls = lastResults.isEmpty
        ? lastResult.map { [$0.publicURL] } ?? []
        : lastResults.map(\.publicURL)
    }
    openURLs(urls)
  }

  func copyHistoryLink(_ entry: UploadHistoryEntry) {
    linkWriter.copy(entry.publicURL.absoluteString)
  }

  func copyAllHistoryLinks() {
    let links = history.map(\.publicURL.absoluteString)
    guard !links.isEmpty else {
      return
    }

    linkWriter.copy(links.joined(separator: "\n"))
  }

  func clearHistory() {
    history = []
    historyStore.clear()
  }

  func removeHistoryEntry(_ entry: UploadHistoryEntry) {
    history.removeAll { $0.id == entry.id }
    if history.isEmpty {
      historyStore.clear()
    } else {
      try? historyStore.save(history)
    }
  }

  private func copyLinks(_ results: [UploadResult], feedbackDuration: Duration = .seconds(1.4)) {
    let links = results.map(\.publicURL.absoluteString)
    guard !links.isEmpty else {
      return
    }

    linkWriter.copy(links.joined(separator: "\n"))
    showCopyConfirmation(duration: feedbackDuration)
  }

  private func presentError(_ message: String, autoDismiss: Bool = false) {
    errorFeedbackTask?.cancel()
    lastError = message

    if autoDismiss {
      scheduleErrorDismissal(for: message)
    }
  }

  private func scheduleErrorDismissal(for message: String) {
    errorFeedbackTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      await MainActor.run {
        if self?.lastError == message {
          self?.lastError = nil
        }
      }
    }
  }

  private func openURLs(_ urls: [URL]) {
    for url in urls {
      NSWorkspace.shared.open(url)
    }
  }

  private func recordHistory(_ uploads: [CompletedUpload]) {
    guard !uploads.isEmpty else {
      return
    }

    history = uploads.map {
      UploadHistoryEntry(
        result: $0.result,
        thumbnailData: $0.thumbnailData,
        displayName: $0.displayName,
        contentType: $0.contentType
      )
    } + history
    try? historyStore.save(history)
  }

  private func showCopyConfirmation(duration: Duration = .seconds(1.4)) {
    copyFeedbackTask?.cancel()
    copyConfirmation = true
    copyFeedbackTask = Task { [weak self] in
      try? await Task.sleep(for: duration)
      await MainActor.run {
        self?.copyConfirmation = false
      }
    }
  }

  nonisolated private static func isTransientError(_ error: Error) -> Bool {
    guard let uploadError = error as? UploadError else {
      return false
    }

    return uploadError == .missingImage
  }

  nonisolated private static func batchFailureMessage(successCount: Int, failedCount: Int) -> String {
    if successCount == 0 {
      return failedCount == 1 ? "1 file failed." : "\(failedCount) files failed."
    }

    let uploaded = successCount == 1 ? "1 uploaded" : "\(successCount) uploaded"
    let failed = failedCount == 1 ? "1 failed" : "\(failedCount) failed"
    return "\(uploaded), \(failed)."
  }

  private func persist() {
    try? settingsStore.save(settings: providers, selectedID: selectedProviderID)
  }

  private func saveCredentialDrafts(for provider: ProviderSettings) {
    if provider.requiresCredential, credentialDraft.nilIfBlankDroppie != nil {
      try? credentialStore.saveCredential(credentialDraft, providerID: provider.id, name: "primary")
    }

    if provider.kind == .amazonS3 || provider.kind == .cloudflareR2 || provider.kind == .s3Compatible {
      if accessKeyIDDraft.nilIfBlankDroppie != nil {
        try? credentialStore.saveCredential(accessKeyIDDraft, providerID: provider.id, name: "accessKeyID")
      }
      if secretAccessKeyDraft.nilIfBlankDroppie != nil {
        try? credentialStore.saveCredential(secretAccessKeyDraft, providerID: provider.id, name: "secretAccessKey")
      }
      if sessionTokenDraft.nilIfBlankDroppie != nil {
        try? credentialStore.saveCredential(sessionTokenDraft, providerID: provider.id, name: "sessionToken")
      }
    }
  }

  private func loadCredentialDrafts(for provider: ProviderSettings) {
    credentialDraft = (try? readCredential(provider: provider, name: "primary")) ?? ""
    if provider.kind == .hereNow, credentialDraft.isEmpty {
      credentialDraft = Self.readHereNowCredentialsFile() ?? ""
    }
    accessKeyIDDraft = (try? readCredential(provider: provider, name: "accessKeyID")) ?? ""
    secretAccessKeyDraft = (try? readCredential(provider: provider, name: "secretAccessKey")) ?? ""
    sessionTokenDraft = (try? readCredential(provider: provider, name: "sessionToken")) ?? ""
  }

  private func credentials(for provider: ProviderSettings) throws -> ProviderCredentials {
    ProviderCredentials(
      primary: try credential(for: provider),
      accessKeyID: try readCredential(provider: provider, name: "accessKeyID"),
      secretAccessKey: try readCredential(provider: provider, name: "secretAccessKey"),
      sessionToken: try readCredential(provider: provider, name: "sessionToken")
    )
  }

  private func credential(for provider: ProviderSettings) throws -> String? {
    do {
      let value = try readCredential(provider: provider, name: "primary")
      if provider.kind == .hereNow, value?.nilIfBlankDroppie == nil, let hereNowKey = Self.readHereNowCredentialsFile() {
        return hereNowKey
      }
      return value
    } catch let error as KeychainError {
      if provider.kind == .hereNow, let hereNowKey = Self.readHereNowCredentialsFile() {
        return hereNowKey
      }

      if error.status == errSecInteractionNotAllowed || error.status == errSecAuthFailed || error.status == errSecUserCanceled {
        throw UploadError.invalidConfiguration("Open Settings to refresh this provider.")
      }

      throw error
    }
  }

  private func readCredential(provider: ProviderSettings, name: String) throws -> String? {
    do {
      return try credentialStore.readCredential(providerID: provider.id, name: name)
    } catch let error as KeychainError {
      if error.status == errSecInteractionNotAllowed || error.status == errSecAuthFailed || error.status == errSecUserCanceled {
        throw UploadError.invalidConfiguration("Open Settings to refresh this provider.")
      }

      throw error
    }
  }

  nonisolated private static func thumbnailData(from image: ClipboardImage) -> Data? {
    guard image.isImage,
          let source = CGImageSourceCreateWithData(image.data as CFData, nil) else {
      return nil
    }

    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCache: false,
      kCGImageSourceThumbnailMaxPixelSize: 96
    ] as CFDictionary

    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options),
          let data = NSMutableData(capacity: 8 * 1024),
          let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
      return nil
    }

    let properties = [kCGImageDestinationLossyCompressionQuality: 0.72] as CFDictionary
    CGImageDestinationAddImage(destination, thumbnail, properties)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
  }

  private static func previewImage(from data: Data?) -> NSImage? {
    guard let data else {
      return nil
    }
    return NSImage(data: data)
  }

  private static func readHereNowCredentialsFile() -> String? {
    let url = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".herenow")
      .appendingPathComponent("credentials")

    guard let rawValue = try? String(contentsOf: url, encoding: .utf8),
          let value = rawValue.nilIfBlankDroppie else {
      return nil
    }

    return value
  }
}

enum UploadStatus: Equatable {
  case idle
  case uploading
  case finished
  case failed
}
