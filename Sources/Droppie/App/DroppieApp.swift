import AppKit
import DroppieCore
import SwiftUI

@main
struct DroppieApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SetupView(model: appDelegate.model)
        .frame(width: 900, height: 680)
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = DroppieModel()
  let updateController = UpdateController()
  private var statusItemController: StatusItemController?
  private var settingsWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    statusItemController = StatusItemController(model: model, updateController: updateController) { [weak self] in
      self?.showSettingsWindow()
    }
  }

  func showSettingsWindow() {
    if let settingsWindow {
      settingsWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let hostingView = NSHostingView(rootView: SetupView(model: model))
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 900, height: 680),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Droppie"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask.insert(.fullSizeContentView)
    window.isMovableByWindowBackground = true
    window.isOpaque = false
    window.backgroundColor = .clear
    window.contentView = hostingView
    window.center()
    window.isReleasedWhenClosed = false
    settingsWindow = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
