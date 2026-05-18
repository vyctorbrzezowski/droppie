import Foundation

public extension String {
  var trimmedDroppie: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var nilIfBlankDroppie: String? {
    let trimmed = trimmedDroppie
    return trimmed.isEmpty ? nil : trimmed
  }
}

public extension URL {
  func appendingPathComponentPreservingDirectory(_ component: String) -> URL {
    if absoluteString.hasSuffix("/") {
      return appendingPathComponent(component)
    }

    return URL(string: absoluteString + "/")!.appendingPathComponent(component)
  }
}
