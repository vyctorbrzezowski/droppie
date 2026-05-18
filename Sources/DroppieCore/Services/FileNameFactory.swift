import Foundation

public struct FileNameFactory: Sendable {
  public init() {}

  public func makeFileName(extension fileExtension: String, date: Date = Date()) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let stamp = formatter.string(from: date)
      .replacingOccurrences(of: ":", with: "-")
      .replacingOccurrences(of: ".", with: "-")
    return "droppie-\(stamp).\(fileExtension)"
  }
}
