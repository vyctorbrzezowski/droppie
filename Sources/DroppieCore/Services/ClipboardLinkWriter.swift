import AppKit
import Foundation

public protocol ClipboardLinkWriting: Sendable {
  func copy(_ value: String)
}

public struct PasteboardLinkWriter: ClipboardLinkWriting, @unchecked Sendable {
  private let pasteboard: NSPasteboard

  public init(pasteboard: NSPasteboard = .general) {
    self.pasteboard = pasteboard
  }

  public func copy(_ value: String) {
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
  }
}
