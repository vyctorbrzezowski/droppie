import AppKit
import SwiftUI

struct PasteCaptureView: NSViewRepresentable {
  var onPaste: () -> Void

  func makeNSView(context: Context) -> PasteCaptureNSView {
    let view = PasteCaptureNSView()
    view.onPaste = onPaste
    DispatchQueue.main.async {
      view.window?.makeFirstResponder(view)
    }
    return view
  }

  func updateNSView(_ nsView: PasteCaptureNSView, context: Context) {
    nsView.onPaste = onPaste
  }
}

final class PasteCaptureNSView: NSView {
  var onPaste: (() -> Void)?

  override var acceptsFirstResponder: Bool {
    true
  }

  override func keyDown(with event: NSEvent) {
    let isPasteKey = event.charactersIgnoringModifiers?.lowercased() == "v"
    let hasPasteModifier = event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)

    if isPasteKey && hasPasteModifier {
      onPaste?()
      return
    }

    super.keyDown(with: event)
  }
}
