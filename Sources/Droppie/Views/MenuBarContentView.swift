import AppKit
import DroppieCore
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarContentView: View {
  @ObservedObject var model: DroppieModel
  @ObservedObject var updateController: UpdateController
  var openSettings: () -> Void
  @State private var selectedTab: MenuTab = .upload

  var body: some View {
    VStack(spacing: 0) {
      PasteCaptureView {
        selectedTab = .upload
        model.uploadClipboard()
      }
      .frame(width: 0, height: 0)

      topBar
      HairlineSeparator()

      content

      controlVPasteShortcut
    }
    .frame(width: DroppieTheme.popoverWidth)
    .frame(maxHeight: DroppieTheme.maxPopoverHeight, alignment: .top)
    .background(.ultraThinMaterial)
    .onDrop(of: [.fileURL], isTargeted: fileDropTargetBinding) { providers in
      handleFileDrop(providers)
    }
    .onChange(of: model.status) { _, status in
      if status == .uploading {
        selectedTab = .upload
      }
    }
    .onChange(of: model.isDropTargeted) { _, isDropTargeted in
      if isDropTargeted {
        selectedTab = .upload
      }
    }
  }

  private var topBar: some View {
    HStack(alignment: .center, spacing: 8) {
      MenuTabBar(selectedTab: $selectedTab)

      Spacer(minLength: 4)

      ProviderPicker(model: model, openSettings: openSettings)
        .frame(maxWidth: .infinity, alignment: .trailing)

      SettingsMenuButton(updateController: updateController, openSettings: openSettings)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private var content: some View {
    switch selectedTab {
    case .upload:
      UploadPane(model: model, openSettings: openSettings)
    case .history:
      HistoryPane(model: model, maxListHeight: DroppieTheme.maxHistoryListHeight)
    }
  }

  private var controlVPasteShortcut: some View {
    Button {
      selectedTab = .upload
      model.uploadClipboard()
    } label: {
      EmptyView()
    }
    .keyboardShortcut("v", modifiers: [.control])
    .frame(width: 0, height: 0)
    .opacity(0)
  }

  private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
    let fileProviders = providers.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
    }
    guard !fileProviders.isEmpty else {
      return false
    }

    selectedTab = .upload
    let group = DispatchGroup()
    let lock = NSLock()
    var urls = Array<URL?>(repeating: nil, count: fileProviders.count)

    for (index, provider) in fileProviders.enumerated() {
      group.enter()
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
        defer { group.leave() }
        guard let url = DroppedFileURLDecoder.fileURL(from: item) else {
          return
        }

        lock.lock()
        urls[index] = url
        lock.unlock()
      }
    }

    group.notify(queue: .main) {
      let droppedURLs = urls.compactMap { $0 }
      if !droppedURLs.isEmpty {
        selectedTab = .upload
        model.uploadDroppedFiles(droppedURLs)
      } else {
        model.isDropTargeted = false
      }
    }

    return true
  }

  private var fileDropTargetBinding: Binding<Bool> {
    Binding(
      get: { model.isDropTargeted },
      set: { model.isDropTargeted = $0 }
    )
  }
}

enum MenuTab: String, CaseIterable, Identifiable {
  case upload
  case history

  var id: String { rawValue }

  var title: String {
    switch self {
    case .upload:
      return "Upload"
    case .history:
      return "History"
    }
  }
}
