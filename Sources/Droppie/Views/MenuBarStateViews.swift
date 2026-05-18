import AppKit
import DroppieCore
import SwiftUI
import UniformTypeIdentifiers

struct MenuTabBar: View {
  @Binding var selectedTab: MenuTab

  var body: some View {
    HStack(spacing: 2) {
      ForEach(MenuTab.allCases) { tab in
        Button {
          selectedTab = tab
        } label: {
          Text(tab.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
            .lineLimit(1)
            .frame(height: 24)
            .padding(.horizontal, 9)
            .background(
              selectedTab == tab ? DroppieTheme.selectedFill : Color.clear,
              in: RoundedRectangle(cornerRadius: DroppieTheme.chipRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(2)
    .background(
      DroppieTheme.controlFill,
      in: RoundedRectangle(cornerRadius: DroppieTheme.controlRadius, style: .continuous)
    )
  }
}

struct ProviderPicker: View {
  @ObservedObject var model: DroppieModel
  var openSettings: () -> Void

  var body: some View {
    if model.providers.isEmpty {
      Button {
        openSettings()
      } label: {
        Image(systemName: "plus")
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .help("Add provider")
      .accessibilityLabel("Add provider")
    } else {
      Menu {
        ForEach(model.providers) { provider in
          Button {
            model.selectProvider(provider)
          } label: {
            if provider.id == model.selectedProviderID {
              Label(provider.name, systemImage: "checkmark")
            } else {
              Text(provider.name)
            }
          }
        }

        Divider()
        Button("Manage") {
          openSettings()
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "cloud")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)

          Text(selectedProviderName)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)

          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(model.isUploading ? .tertiary : .secondary)
      }
      .menuStyle(.borderlessButton)
      .disabled(model.isUploading)
      .fixedSize(horizontal: true, vertical: false)
      .help("Provider")
      .accessibilityLabel("Provider")
    }
  }

  private var selectedProviderName: String {
    model.selectedProvider?.name ?? "Provider"
  }

  private var selectedProviderKind: UploadProviderKind {
    model.selectedProvider?.kind ?? .hereNow
  }
}

struct SettingsMenuButton: View {
  @ObservedObject var updateController: UpdateController
  var openSettings: () -> Void

  var body: some View {
    Menu {
      Button {
        openSettings()
      } label: {
        Label("Manage providers", systemImage: "cloud")
      }

      Button {
        updateController.checkForUpdates()
      } label: {
        Label("Check for updates", systemImage: "arrow.triangle.2.circlepath")
      }
      .disabled(!updateController.canCheckForUpdates)

      Divider()

      Button {
        NSApp.terminate(nil)
      } label: {
        Label("Quit app", systemImage: "power")
      }
    } label: {
      Image(systemName: "gearshape.fill")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 22, height: 22)
        .contentShape(Circle())
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .tint(.secondary)
    .fixedSize()
    .help("Settings")
    .accessibilityLabel("Settings")
  }
}

struct UploadPane: View {
  @ObservedObject var model: DroppieModel
  var openSettings: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      uploadRow

      if let error = model.lastError {
        ErrorRow(message: error, canRetry: model.canRetryLastError) {
          model.uploadClipboard()
        } dismiss: {
          model.dismissLastError()
        }
      }

      if let result = model.lastResult {
        HairlineSeparator()
          .padding(.vertical, 2)
        LatestLinkSection(model: model, result: result)
      }
    }
    .padding(8)
  }

  @ViewBuilder
  private var uploadRow: some View {
    if !model.hasConfiguredProvider {
      Button {
        openSettings()
      } label: {
        UploadStatusPanel(
          title: "Open settings",
          systemImage: "gearshape",
          isActive: false,
          completedCount: 0,
          totalCount: 0,
          shortcut: nil
        )
      }
      .buttonStyle(SurfaceButtonStyle())
      .help("Open settings")
      .accessibilityLabel("Open settings")
    } else if model.isUploading {
      UploadStatusPanel(
        title: uploadTitle,
        systemImage: "arrow.up.doc",
        isActive: true,
        completedCount: model.batchCompletedCount,
        totalCount: model.batchTotalCount,
        shortcut: nil
      )
    } else if model.lastResult == nil {
      VStack(spacing: 8) {
        Button {
          model.uploadClipboard()
        } label: {
          UploadStatusPanel(
            title: "Paste to upload",
            systemImage: "clipboard",
            isActive: false,
            completedCount: 0,
            totalCount: 0,
            shortcut: "⌘V"
          )
        }
        .buttonStyle(SurfaceButtonStyle())
        .keyboardShortcut("v", modifiers: [.command])
        .help("Paste to upload")
        .accessibilityLabel("Paste to upload")

        Button {
          model.chooseFilesForUpload()
        } label: {
          UploadDropArea(
            title: model.isDropTargeted ? "Drop to upload" : "Select files",
            actionText: model.isDropTargeted ? "Release files here" : "or drop them here",
            isDropTargeted: model.isDropTargeted
          )
          .contentShape(
            UnevenRoundedRectangle(
              cornerRadii: .init(
                topLeading: DroppieTheme.controlRadius,
                bottomLeading: 18,
                bottomTrailing: 18,
                topTrailing: DroppieTheme.controlRadius
              ),
              style: .continuous
            )
          )
        }
        .buttonStyle(.plain)
        .help(model.isDropTargeted ? "Drop files to upload" : "Choose files")
        .accessibilityLabel(model.isDropTargeted ? "Drop files to upload" : "Choose files")
      }
    } else {
      EmptyView()
    }
  }

  private var uploadTitle: String {
    if model.batchTotalCount > 1, model.isUploading {
      return "Uploading \(model.batchCompletedCount)/\(model.batchTotalCount)"
    }

    return model.isUploading ? "Uploading" : "Drop or choose files"
  }
}

struct UploadStatusPanel: View {
  var title: String
  var systemImage: String
  var isActive: Bool
  var completedCount: Int
  var totalCount: Int
  var shortcut: String?

  var body: some View {
    HStack(spacing: 10) {
      UploadStatusGlyph(
        systemImage: systemImage,
        isActive: isActive,
        isDropTargeted: false,
        isQuiet: isShortcutAction
      )

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 13, weight: isShortcutAction ? .medium : .semibold))
          .foregroundStyle(isShortcutAction ? Color.primary.opacity(0.82) : Color.primary)
          .lineLimit(1)

        if showsBatchProgress {
          ProgressView(value: Double(completedCount), total: Double(totalCount))
            .progressViewStyle(.linear)
            .controlSize(.small)
        }
      }

      Spacer(minLength: 8)

      if let shortcut, !isActive {
        Text(shortcut)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Color.primary.opacity(0.88))
          .padding(.horizontal, 8)
          .frame(height: 22)
          .background(
            Color.primary.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .stroke(Color.primary.opacity(0.16), lineWidth: 1)
          }
      }
    }
    .frame(height: 46)
    .padding(.horizontal, 10)
    .droppieActionSurface(cornerRadius: DroppieTheme.controlRadius, isHighlighted: false, isQuiet: isShortcutAction)
  }

  private var showsBatchProgress: Bool {
    isActive && totalCount > 1
  }

  private var isShortcutAction: Bool {
    shortcut != nil && !isActive
  }
}

struct UploadDropArea: View {
  var title: String
  var actionText: String
  var isDropTargeted: Bool

  var body: some View {
    ZStack {
      DropAreaDecoration(isDropTargeted: isDropTargeted)

      VStack(spacing: 8) {
        Label(title, systemImage: isDropTargeted ? "arrow.down.doc" : "folder.badge.plus")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(isDropTargeted ? Color.accentColor : Color.primary)
          .labelStyle(.titleAndIcon)
          .lineLimit(1)
          .padding(.leading, 11)
          .padding(.trailing, 13)
          .frame(height: 28)
          .background(
            isDropTargeted ? Color.accentColor.opacity(0.12) : DroppieTheme.controlFill,
            in: Capsule(style: .continuous)
          )
          .overlay {
            Capsule(style: .continuous)
              .stroke(
                isDropTargeted ? Color.accentColor.opacity(0.22) : DroppieTheme.divider.opacity(0.8),
                lineWidth: 1
              )
          }

        Text(actionText)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(isDropTargeted ? Color.accentColor.opacity(0.92) : Color.secondary)
          .multilineTextAlignment(.center)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 92)
    .padding(.horizontal, 14)
    .droppieDropSurface(isHighlighted: isDropTargeted)
  }
}

private struct DropAreaDecoration: View {
  var isDropTargeted: Bool

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height
      let accentOpacity = isDropTargeted ? 0.12 : 0.055
      let railOpacity = isDropTargeted ? 0.18 : 0.09
      let iconOpacity = isDropTargeted ? 0.32 : 0.17

      ZStack {
        RadialGradient(
          colors: [
            Color.accentColor.opacity(accentOpacity),
            Color.accentColor.opacity(accentOpacity * 0.45),
            Color.clear
          ],
          center: .center,
          startRadius: 0,
          endRadius: max(width, height) * 0.58
        )

        ForEach(0..<3, id: \.self) { index in
          RoundedRectangle(cornerRadius: 26 + CGFloat(index) * 8, style: .continuous)
            .stroke(
              Color.accentColor.opacity(railOpacity - Double(index) * 0.035),
              style: StrokeStyle(lineWidth: 1, dash: [5, 9])
            )
            .frame(
              width: width * (0.62 + CGFloat(index) * 0.17),
              height: height * (0.54 + CGFloat(index) * 0.16)
            )
            .position(x: width / 2, y: height / 2)
        }

        DropAreaDecorationIcon(systemName: "doc", x: width * 0.16, y: height * 0.34, rotation: -9, opacity: iconOpacity)
        DropAreaDecorationIcon(systemName: "photo", x: width * 0.83, y: height * 0.30, rotation: 8, opacity: iconOpacity)
        DropAreaDecorationIcon(systemName: "play.rectangle", x: width * 0.22, y: height * 0.72, rotation: 7, opacity: iconOpacity * 0.86)
        DropAreaDecorationIcon(systemName: "link", x: width * 0.77, y: height * 0.72, rotation: -8, opacity: iconOpacity * 0.86)
      }
      .frame(width: width, height: height)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct DropAreaDecorationIcon: View {
  var systemName: String
  var x: CGFloat
  var y: CGFloat
  var rotation: Double
  var opacity: Double

  var body: some View {
    Image(systemName: systemName)
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(Color.primary.opacity(opacity))
      .frame(width: 25, height: 22)
      .background(
        Color.primary.opacity(opacity * 0.22),
        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(Color.primary.opacity(opacity * 0.28), lineWidth: 1)
      }
      .rotationEffect(.degrees(rotation))
      .position(x: x, y: y)
  }
}

struct UploadStatusGlyph: View {
  var systemImage: String
  var isActive: Bool
  var isDropTargeted: Bool
  var isQuiet = false

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(iconBackground)

      if isActive, !isDropTargeted {
        TimelineView(.animation) { context in
          ZStack {
            Circle()
              .trim(from: 0.16, to: 0.82)
              .stroke(
                Color.accentColor.opacity(0.68),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
              )
              .rotationEffect(rotation(for: context.date))

            Image(systemName: "arrow.up")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(Color.accentColor)
          }
          .frame(width: 19, height: 19)
        }
      } else {
        Image(systemName: systemImage)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(isDropTargeted ? Color.accentColor : iconForeground)
      }
    }
    .frame(width: 30, height: 30)
  }

  private var iconBackground: Color {
    if isQuiet {
      return Color.primary.opacity(0.035)
    }

    return isActive || isDropTargeted ? Color.accentColor.opacity(0.16) : DroppieTheme.controlFill
  }

  private var iconForeground: Color {
    isQuiet ? Color.primary.opacity(0.48) : Color.secondary
  }

  private func rotation(for date: Date) -> Angle {
    let duration = 0.9
    let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration) / duration
    return .degrees(progress * 360)
  }
}

struct ErrorRow: View {
  var message: String
  var canRetry: Bool
  var retry: () -> Void
  var dismiss: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(DroppieTheme.warning)
      Text(message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
      Spacer()

      if canRetry {
        Button {
          retry()
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .controlSize(.small)
        .buttonStyle(.borderless)
        .help("Retry")
        .accessibilityLabel("Retry")
      }

      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark")
      }
      .controlSize(.small)
      .buttonStyle(.borderless)
      .help("Dismiss")
      .accessibilityLabel("Dismiss")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      DroppieTheme.warning.opacity(0.10),
      in: RoundedRectangle(cornerRadius: DroppieTheme.controlRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: DroppieTheme.controlRadius, style: .continuous)
        .stroke(DroppieTheme.warning.opacity(0.18), lineWidth: 1)
    }
  }
}

struct LatestLinkSection: View {
  @ObservedObject var model: DroppieModel
  var result: UploadResult

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if shouldShowSummary {
        Text(summaryTitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack(alignment: .top, spacing: 12) {
        if model.lastResults.count == 1, let item = model.lastUploadItems.first {
          Link(destination: item.openURL) {
            UploadPreviewThumbnail(
              data: item.thumbnailData,
              contentType: item.contentType,
              fileExtension: item.publicURL.pathExtension,
              size: 42
            )
          }
          .buttonStyle(.plain)
          .help("Open")
          .accessibilityLabel("Open uploaded file")
        }

        VStack(alignment: .leading, spacing: 9) {
          linkList

          HStack(spacing: 8) {
            Button {
              model.lastResults.count > 1 ? model.copyAllLinks() : model.copyLastLink()
            } label: {
              Label(copyTitle, systemImage: model.copyConfirmation ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(ActionChipButtonStyle(tone: model.copyConfirmation ? .success : .default))
            .help(model.lastResults.count > 1 ? "Copy all links" : "Copy link")
            .accessibilityLabel(model.lastResults.count > 1 ? "Copy all links" : "Copy link")

            Button {
              model.openLastLinks()
            } label: {
              HStack(spacing: 5) {
                Image(systemName: "arrow.up.right")
                  .font(.caption2)
                Text(model.lastResults.count > 1 ? "Open All" : "Open")
              }
            }
            .buttonStyle(ActionChipButtonStyle())
            .help(model.lastResults.count > 1 ? "Open all links" : "Open")
            .accessibilityLabel(model.lastResults.count > 1 ? "Open all uploaded files" : "Open uploaded file")

            Spacer()
          }
          .controlSize(.small)
        }
      }
    }
    .padding(.vertical, 2)
  }

  @ViewBuilder
  private var linkList: some View {
    if model.lastResults.count > 1 {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(model.lastUploadItems) { item in
            LinkRow(item: item) {
              model.copyLink(item.publicURL, showsFeedback: false)
            }
          }
        }
      }
      .frame(maxHeight: 188)
    } else {
      if let item = model.lastUploadItems.first, let displayName = item.displayName {
        VStack(alignment: .leading, spacing: 2) {
          Text(displayName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.middle)
          Text(item.publicURL.absoluteString)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
        }
      } else {
        Text(result.publicURL.absoluteString)
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)
      }
    }
  }

  private var shouldShowSummary: Bool {
    model.lastResults.count > 1 || model.lastBatchSkippedCount > 0 || model.lastBatchFailedCount > 0
  }

  private var summaryTitle: String {
    let count = model.lastResults.count
    var parts = [count > 1 ? "\(count) links" : "Latest"]
    if model.lastBatchSkippedCount > 0 {
      parts.append("\(model.lastBatchSkippedCount) skipped")
    }
    if model.lastBatchFailedCount > 0 {
      parts.append("\(model.lastBatchFailedCount) failed")
    }
    return parts.joined(separator: " · ")
  }

  private var copyTitle: String {
    if model.copyConfirmation {
      return "Copied"
    }

    return model.lastResults.count > 1 ? "Copy All" : "Copy"
  }
}

struct UploadPreviewThumbnail: View {
  var data: Data?
  var contentType: String?
  var fileExtension: String?
  var size: CGFloat

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: DroppieTheme.controlRadius, style: .continuous)
        .fill(DroppieTheme.controlFill)

      if let image {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else {
        Image(systemName: isVideo ? "play.rectangle" : "photo")
          .font(.system(size: size < 36 ? 12 : 16, weight: .regular))
          .foregroundStyle(.tertiary)
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: DroppieTheme.controlRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: DroppieTheme.controlRadius, style: .continuous)
        .stroke(DroppieTheme.divider.opacity(0.7), lineWidth: 1)
    }
    .overlay(alignment: .topTrailing) {
      ThumbnailOpenIndicator(size: size < 36 ? 11 : 13)
        .padding(size < 36 ? 2 : 3)
    }
  }

  private var image: NSImage? {
    guard let data else {
      return nil
    }

    return NSImage(data: data)
  }

  private var isVideo: Bool {
    if contentType?.lowercased().hasPrefix("video/") == true {
      return true
    }

    guard let fileExtension,
          let type = UTType(filenameExtension: fileExtension) else {
      return false
    }

    return type.conforms(to: .movie)
  }
}

struct ThumbnailOpenIndicator: View {
  var size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(.black.opacity(0.58))
      Image(systemName: "arrow.up.right")
        .font(.system(size: size * 0.52, weight: .semibold))
        .foregroundStyle(.white.opacity(0.9))
    }
    .frame(width: size, height: size)
    .allowsHitTesting(false)
  }
}

struct HistoryPane: View {
  @ObservedObject var model: DroppieModel
  var maxListHeight: CGFloat
  @State private var isConfirmingClear = false
  @State private var isCopyAllCopied = false
  @State private var copyFeedbackTask: Task<Void, Never>?
  @State private var clearFeedbackTask: Task<Void, Never>?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if model.history.isEmpty {
        Text("No history")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 112, alignment: .center)
      } else {
        HStack {
          Button {
            copyAllHistory()
          } label: {
            Label(isCopyAllCopied ? "Copied" : "Copy All", systemImage: isCopyAllCopied ? "checkmark" : "doc.on.doc")
          }
          .buttonStyle(ActionChipButtonStyle(tone: isCopyAllCopied ? .success : .default))
          .help("Copy all history links")
          .accessibilityLabel("Copy all history links")

          Spacer()

          if isConfirmingClear {
            HStack(spacing: 2) {
              Button {
                cancelClearConfirmation()
              } label: {
                Image(systemName: "xmark")
              }
              .buttonStyle(InlineIconButtonStyle(tone: .copy))
              .help("Cancel")
              .accessibilityLabel("Cancel clearing history")

              Button(role: .destructive) {
                model.clearHistory()
              } label: {
                Image(systemName: "trash.fill")
              }
              .buttonStyle(InlineIconButtonStyle(tone: .destructive))
              .help("Confirm clear history")
              .accessibilityLabel("Confirm clear history")
            }
          } else {
            Button(role: .destructive) {
              confirmClearHistory()
            } label: {
              Image(systemName: "trash")
            }
            .buttonStyle(ActionChipButtonStyle())
            .help("Clear history")
            .accessibilityLabel("Clear history")
          }
        }

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleHistory.enumerated()), id: \.element.id) { index, entry in
              HistoryRow(model: model, entry: entry)
              if index < visibleHistory.count - 1 {
                Divider()
              }
            }
          }
        }
        .frame(height: historyListHeight)
      }
    }
    .padding(8)
    .onDisappear {
      copyFeedbackTask?.cancel()
      clearFeedbackTask?.cancel()
    }
  }

  private var visibleHistory: [UploadHistoryEntry] {
    Array(model.history.prefix(50))
  }

  private var historyListHeight: CGFloat {
    let rowHeight: CGFloat = 45
    let dividerHeight = CGFloat(max(0, visibleHistory.count - 1))
    let contentHeight = CGFloat(visibleHistory.count) * rowHeight + dividerHeight
    return min(contentHeight, maxListHeight)
  }

  private func copyAllHistory() {
    model.copyAllHistoryLinks()
    copyFeedbackTask?.cancel()
    withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
      isCopyAllCopied = true
    }
    copyFeedbackTask = Task {
      try? await Task.sleep(for: .seconds(1))
      await MainActor.run {
        withAnimation(.easeOut(duration: 0.12)) {
          isCopyAllCopied = false
        }
      }
    }
  }

  private func confirmClearHistory() {
    clearFeedbackTask?.cancel()
    withAnimation(.easeOut(duration: 0.12)) {
      isConfirmingClear = true
    }
    clearFeedbackTask = Task {
      try? await Task.sleep(for: .seconds(3))
      await MainActor.run {
        withAnimation(.easeOut(duration: 0.12)) {
          isConfirmingClear = false
        }
      }
    }
  }

  private func cancelClearConfirmation() {
    clearFeedbackTask?.cancel()
    withAnimation(.easeOut(duration: 0.12)) {
      isConfirmingClear = false
    }
  }
}

struct HistoryRow: View {
  @ObservedObject var model: DroppieModel
  var entry: UploadHistoryEntry
  @State private var isHovering = false
  @State private var isCopied = false
  @State private var isConfirmingDelete = false
  @State private var copyFeedbackTask: Task<Void, Never>?
  @State private var deleteFeedbackTask: Task<Void, Never>?

  var body: some View {
    HStack(spacing: 8) {
      Link(destination: openURL) {
        HistoryThumbnail(
          data: entry.thumbnailData,
          contentType: entry.contentType,
          fileExtension: entry.publicURL.pathExtension,
          showsOpenIndicator: isHovering
        )
      }
      .buttonStyle(.plain)
      .help("Open")
      .accessibilityLabel("Open uploaded file")

      HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
          if let displayName = entry.displayName?.nilIfBlankDroppie {
            Text(displayName)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)
              .truncationMode(.middle)
            Text(entry.publicURL.absoluteString)
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          } else {
            Text(entry.publicURL.absoluteString)
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .lineLimit(1)
              .truncationMode(.middle)
            Text(entry.provider.title)
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }

        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .onTapGesture {
        copyEntry()
      }

      HStack(spacing: 2) {
        if isConfirmingDelete {
          Button {
            cancelDeleteConfirmation()
          } label: {
            Image(systemName: "xmark")
          }
          .buttonStyle(InlineIconButtonStyle(tone: .copy))
          .help("Cancel")
          .accessibilityLabel("Cancel removing history item")

          Button(role: .destructive) {
            model.removeHistoryEntry(entry)
          } label: {
            Image(systemName: "trash.fill")
          }
          .buttonStyle(InlineIconButtonStyle(tone: .destructive))
          .help("Confirm remove")
          .accessibilityLabel("Confirm remove history item")
        } else {
          Button(role: .destructive) {
            confirmDelete()
          } label: {
            Image(systemName: "trash")
          }
          .buttonStyle(InlineIconButtonStyle(tone: .destructive))
          .opacity(isHovering ? 1 : 0)
          .allowsHitTesting(isHovering)
          .help("Remove")
          .accessibilityLabel("Remove history item")

          Button {
            copyEntry()
          } label: {
            Image(systemName: isCopied ? "checkmark" : "square.on.square")
              .scaleEffect(isCopied ? 1.08 : 1)
              .animation(.spring(response: 0.18, dampingFraction: 0.72), value: isCopied)
          }
          .buttonStyle(InlineIconButtonStyle(tone: isCopied ? .success : .copy))
          .help("Copy link")
          .accessibilityLabel("Copy link")

          Link(destination: openURL) {
            Image(systemName: "arrow.up.right")
          }
          .buttonStyle(InlineIconButtonStyle(tone: .open))
          .help("Open")
          .accessibilityLabel("Open uploaded file")
        }
      }
      .frame(width: 68, alignment: .trailing)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .background(isHovering ? DroppieTheme.rowHover : Color.clear)
    .onHover { isHovering = $0 }
    .onDisappear {
      copyFeedbackTask?.cancel()
      deleteFeedbackTask?.cancel()
    }
  }

  private var openURL: URL {
    if entry.provider == .hereNow, isVideo {
      return entry.publicURL.deletingLastPathComponent()
    }

    return entry.publicURL
  }

  private var isVideo: Bool {
    if entry.contentType?.lowercased().hasPrefix("video/") == true {
      return true
    }

    guard let type = UTType(filenameExtension: entry.publicURL.pathExtension) else {
      return false
    }

    return type.conforms(to: .movie)
  }

  private func copyEntry() {
    model.copyHistoryLink(entry)
    showCopyFeedback()
  }

  private func showCopyFeedback() {
    copyFeedbackTask?.cancel()
    withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
      isCopied = true
    }

    copyFeedbackTask = Task {
      try? await Task.sleep(for: .seconds(1))
      await MainActor.run {
        withAnimation(.easeOut(duration: 0.12)) {
          isCopied = false
        }
      }
    }
  }

  private func confirmDelete() {
    deleteFeedbackTask?.cancel()
    withAnimation(.easeOut(duration: 0.12)) {
      isConfirmingDelete = true
    }
    deleteFeedbackTask = Task {
      try? await Task.sleep(for: .seconds(3))
      await MainActor.run {
        withAnimation(.easeOut(duration: 0.12)) {
          isConfirmingDelete = false
        }
      }
    }
  }

  private func cancelDeleteConfirmation() {
    deleteFeedbackTask?.cancel()
    withAnimation(.easeOut(duration: 0.12)) {
      isConfirmingDelete = false
    }
  }
}

struct HistoryThumbnail: View {
  var data: Data?
  var contentType: String?
  var fileExtension: String?
  var showsOpenIndicator = false

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(DroppieTheme.controlFill)

      if let image {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
      } else {
        Image(systemName: isVideo ? "play.rectangle" : "photo")
          .font(.system(size: 12, weight: .regular))
          .foregroundStyle(.tertiary)
      }
    }
    .frame(width: 32, height: 32)
    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .stroke(DroppieTheme.divider.opacity(0.55), lineWidth: 1)
    }
    .overlay(alignment: .topTrailing) {
      if showsOpenIndicator {
        ThumbnailOpenIndicator(size: 12)
          .padding(2)
      }
    }
  }

  private var image: NSImage? {
    guard let data else {
      return nil
    }

    return NSImage(data: data)
  }

  private var isVideo: Bool {
    if contentType?.lowercased().hasPrefix("video/") == true {
      return true
    }

    guard let fileExtension,
          let type = UTType(filenameExtension: fileExtension) else {
      return false
    }

    return type.conforms(to: .movie)
  }
}

struct LinkRow: View {
  var item: UploadDisplayItem
  var copy: () -> Void
  @State private var isHovering = false
  @State private var isCopied = false
  @State private var copyFeedbackTask: Task<Void, Never>?

  var body: some View {
    HStack(spacing: 8) {
      Link(destination: item.openURL) {
        UploadPreviewThumbnail(
          data: item.thumbnailData,
          contentType: item.contentType,
          fileExtension: item.publicURL.pathExtension,
          size: 30
        )
      }
      .buttonStyle(.plain)
      .help("Open")
      .accessibilityLabel("Open uploaded file")

      VStack(alignment: .leading, spacing: 2) {
        Text(item.displayName ?? item.publicURL.lastPathComponent)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
          .truncationMode(.middle)
        Text(item.publicURL.absoluteString)
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)
      }

      Spacer(minLength: 6)

      Button {
        copyItem()
      } label: {
        Image(systemName: isCopied ? "checkmark" : "square.on.square")
          .scaleEffect(isCopied ? 1.08 : 1)
          .animation(.spring(response: 0.18, dampingFraction: 0.72), value: isCopied)
      }
      .buttonStyle(InlineIconButtonStyle(tone: isCopied ? .success : .copy))
      .help("Copy link")
      .accessibilityLabel("Copy link")

      Link(destination: item.openURL) {
        Image(systemName: "arrow.up.right")
      }
      .buttonStyle(InlineIconButtonStyle(tone: .open))
      .help("Open")
      .accessibilityLabel("Open uploaded file")
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 5)
    .background(isHovering ? DroppieTheme.rowHover : Color.clear)
    .onHover { isHovering = $0 }
    .onDisappear {
      copyFeedbackTask?.cancel()
    }
  }

  private func copyItem() {
    copy()
    copyFeedbackTask?.cancel()
    withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
      isCopied = true
    }
    copyFeedbackTask = Task {
      try? await Task.sleep(for: .seconds(1))
      await MainActor.run {
        withAnimation(.easeOut(duration: 0.12)) {
          isCopied = false
        }
      }
    }
  }
}

struct HairlineSeparator: View {
  var body: some View {
    Rectangle()
      .fill(DroppieTheme.divider)
      .frame(height: 1)
  }
}

struct SurfaceButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.82 : 1)
      .scaleEffect(configuration.isPressed ? 0.992 : 1)
      .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
  }
}

enum ActionChipTone {
  case `default`
  case success
}

struct ActionChipButtonStyle: ButtonStyle {
  var tone: ActionChipTone = .default

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(configuration.isPressed ? pressedColor : color)
      .padding(.horizontal, 7)
      .frame(height: 22)
      .background(
        configuration.isPressed ? DroppieTheme.selectedFill : DroppieTheme.controlFill,
        in: RoundedRectangle(cornerRadius: DroppieTheme.chipRadius, style: .continuous)
      )
  }

  private var color: Color {
    switch tone {
    case .default:
      return .secondary
    case .success:
      return DroppieTheme.success
    }
  }

  private var pressedColor: Color {
    switch tone {
    case .default:
      return .primary
    case .success:
      return DroppieTheme.success.opacity(0.82)
    }
  }
}

struct FooterIconButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .regular))
      .symbolRenderingMode(.monochrome)
      .imageScale(.medium)
      .foregroundStyle(configuration.isPressed ? .primary : .secondary)
      .frame(width: 24, height: 22)
      .background(
        configuration.isPressed ? DroppieTheme.controlFill : Color.clear,
        in: RoundedRectangle(cornerRadius: DroppieTheme.chipRadius, style: .continuous)
      )
  }
}

enum InlineActionTone {
  case copy
  case open
  case destructive
  case success
}

struct InlineIconButtonStyle: ButtonStyle {
  var tone: InlineActionTone

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: fontWeight))
      .symbolRenderingMode(.monochrome)
      .imageScale(.medium)
      .foregroundStyle(configuration.isPressed ? pressedColor : color)
      .frame(width: 22, height: 22)
      .contentShape(Rectangle())
      .background(
        configuration.isPressed ? DroppieTheme.controlFill : Color.clear,
        in: RoundedRectangle(cornerRadius: DroppieTheme.chipRadius, style: .continuous)
      )
  }

  private var fontWeight: Font.Weight {
    switch tone {
    case .copy:
      return .medium
    case .open, .destructive, .success:
      return .regular
    }
  }

  private var color: Color {
    switch tone {
    case .copy, .open:
      return Color.primary.opacity(0.56)
    case .destructive:
      return DroppieTheme.danger.opacity(0.76)
    case .success:
      return DroppieTheme.success
    }
  }

  private var pressedColor: Color {
    switch tone {
    case .destructive:
      return DroppieTheme.danger
    case .success:
      return DroppieTheme.success.opacity(0.82)
    case .copy, .open:
      return Color.primary.opacity(0.82)
    }
  }
}

private extension View {
  func droppieActionSurface(cornerRadius: CGFloat, isHighlighted: Bool = false, isQuiet: Bool = false) -> some View {
    background(
      isHighlighted ? Color.accentColor.opacity(0.10) : (isQuiet ? Color.primary.opacity(0.035) : DroppieTheme.actionFill),
      in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .stroke(
          isHighlighted ? Color.accentColor.opacity(0.38) : (isQuiet ? DroppieTheme.divider.opacity(0.55) : DroppieTheme.divider.opacity(0.9)),
          lineWidth: 1
        )
    }
  }

  func droppieDropSurface(isHighlighted: Bool = false) -> some View {
    let shape = UnevenRoundedRectangle(
      cornerRadii: .init(
        topLeading: DroppieTheme.controlRadius,
        bottomLeading: 18,
        bottomTrailing: 18,
        topTrailing: DroppieTheme.controlRadius
      ),
      style: .continuous
    )
    let strokeColor = isHighlighted
      ? Color.accentColor.opacity(0.46)
      : Color.primary.opacity(0.22)

    return background(
      isHighlighted ? Color.accentColor.opacity(0.06) : Color.clear,
      in: shape
    )
    .overlay {
      shape
        .stroke(
          strokeColor,
          style: StrokeStyle(lineWidth: 1, dash: [5, 5])
        )
    }
  }
}
