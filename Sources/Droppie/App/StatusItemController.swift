import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
  private let statusItem: NSStatusItem
  private let dropView = StatusItemDropView(frame: NSRect(x: 0, y: 0, width: 28, height: 22))
  private let popover = NSPopover()
  private let model: DroppieModel
  private let updateController: UpdateController
  private let openSettings: () -> Void
  private var cancellables = Set<AnyCancellable>()
  private var autoCloseTask: Task<Void, Never>?

  init(model: DroppieModel, updateController: UpdateController, openSettings: @escaping () -> Void) {
    self.model = model
    self.updateController = updateController
    self.openSettings = openSettings
    self.statusItem = NSStatusBar.system.statusItem(withLength: 28)
    super.init()
    configureStatusItem()
    configurePopover()
    observeModel()
  }

  private func configureStatusItem() {
    dropView.onClick = { [weak self] in
      self?.togglePopover()
    }
    dropView.onFileDrop = { [weak self] urls in
      self?.handleDrop(urls)
    }
    dropView.onFileDragEntered = { [weak self] in
      self?.model.isDropTargeted = true
      self?.showPopover()
    }
    dropView.onFileDragExited = { [weak self] in
      self?.model.isDropTargeted = false
    }

    statusItem.length = 28
    statusItem.view = dropView
    updateStatusView()
  }

  private func configurePopover() {
    updatePopoverBehavior()
    popover.animates = false
    popover.delegate = self
    popover.contentSize = NSSize(width: DroppieTheme.popoverWidth, height: 1)
    let hostingController = NSHostingController(
      rootView: MenuBarContentView(
        model: model,
        updateController: updateController,
        openSettings: openSettings
      )
    )
    hostingController.sizingOptions = [.preferredContentSize]
    popover.contentViewController = hostingController
  }

  private func observeModel() {
    model.objectWillChange.sink { [weak self] _ in
      Task { @MainActor in
        self?.updateStatusView()
      }
    }
    .store(in: &cancellables)

    model.$status.sink { [weak self] status in
      self?.updatePopoverBehavior()
      self?.updateAutoClose(for: status)
      if status == .uploading, self?.popover.isShown == false {
        self?.showPopover()
      }
    }
    .store(in: &cancellables)
  }

  private func togglePopover() {
    if popover.isShown {
      autoCloseTask?.cancel()
      popover.performClose(nil)
    } else {
      showPopover()
    }
  }

  private func showPopover() {
    guard !popover.isShown else {
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    popover.show(relativeTo: dropView.bounds, of: dropView, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
  }

  private func handleDrop(_ urls: [URL]) {
    model.isDropTargeted = false
    model.uploadDroppedFiles(urls)
    if !popover.isShown {
      showPopover()
    }
  }

  private func updateStatusView() {
    dropView.symbolName = model.isUploading ? "arrow.triangle.2.circlepath" : "photo.on.rectangle.angled"
    dropView.tintColor = statusColor
  }

  private func updatePopoverBehavior() {
    popover.behavior = model.isUploading ? .applicationDefined : .transient
  }

  private func updateAutoClose(for status: UploadStatus) {
    autoCloseTask?.cancel()

    if status == .finished {
      scheduleFinishedAutoClose(after: .seconds(40))
    }
  }

  private func scheduleFinishedAutoClose(after duration: Duration) {
    autoCloseTask?.cancel()
    autoCloseTask = Task { [weak self] in
      try? await Task.sleep(for: duration)
      await MainActor.run {
        guard let self,
              self.model.status == .finished,
              self.popover.isShown else {
          return
        }

        if self.isMouseInsidePopover {
          self.scheduleFinishedAutoClose(after: .seconds(8))
          return
        }

        self.model.clearFinishedUploadSession()
        self.popover.performClose(nil)
      }
    }
  }

  private var isMouseInsidePopover: Bool {
    guard let frame = popover.contentViewController?.view.window?.frame else {
      return false
    }

    return frame.contains(NSEvent.mouseLocation)
  }

  private var statusColor: NSColor {
    if !model.hasConfiguredProvider {
      return .systemOrange
    }

    switch model.status {
    case .idle:
      return .labelColor
    case .uploading:
      return .controlAccentColor
    case .finished:
      return .systemGreen
    case .failed:
      return .systemRed
    }
  }
}

extension StatusItemController: NSPopoverDelegate {
  func popoverDidClose(_ notification: Notification) {
    autoCloseTask?.cancel()
    model.clearFinishedUploadSession()
    model.dismissLastError()
  }
}

final class StatusItemDropView: NSView {
  var onClick: (() -> Void)?
  var onFileDrop: (([URL]) -> Void)?
  var onFileDragEntered: (() -> Void)?
  var onFileDragExited: (() -> Void)?
  var symbolName = "photo.on.rectangle.angled" {
    didSet { needsDisplay = true }
  }
  var tintColor: NSColor? {
    didSet { needsDisplay = true }
  }

  private var isDropTargeted = false {
    didSet { needsDisplay = true }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setAccessibilityLabel("Droppie")
    registerForDraggedTypes([.fileURL])
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setAccessibilityLabel("Droppie")
    registerForDraggedTypes([.fileURL])
  }

  override func mouseDown(with event: NSEvent) {
    onClick?()
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard !fileURLs(from: sender.draggingPasteboard).isEmpty else {
      return []
    }

    isDropTargeted = true
    onFileDragEntered?()
    return .copy
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    isDropTargeted = false
    onFileDragExited?()
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    fileURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    !fileURLs(from: sender.draggingPasteboard).isEmpty
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    defer {
      isDropTargeted = false
      onFileDragExited?()
    }

    let urls = fileURLs(from: sender.draggingPasteboard)
    guard !urls.isEmpty else {
      return false
    }

    onFileDrop?(urls)
    return true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    if isDropTargeted {
      NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
      NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
    }

    guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Droppie")?.copy() as? NSImage else {
      return
    }
    image.isTemplate = tintColor == nil

    let imageSize = NSSize(width: 17, height: 17)
    let rect = NSRect(
      x: bounds.midX - imageSize.width / 2,
      y: bounds.midY - imageSize.height / 2,
      width: imageSize.width,
      height: imageSize.height
    )

    if let tintColor {
      image.lockFocus()
      tintColor.set()
      NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
      image.unlockFocus()
    }

    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
  }

  private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
      return []
    }

    return urls.filter { url in
      (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
  }
}
