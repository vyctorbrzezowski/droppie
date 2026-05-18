import AppKit
import Foundation
@testable import DroppieCore

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
  struct RecordedRequest {
    var request: URLRequest
    var body: Data?
  }

  var responses: [(Data, HTTPURLResponse)] = []
  var recordedRequests: [RecordedRequest] = []

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    recordedRequests.append(.init(request: request, body: request.httpBody))
    return responses.removeFirst()
  }

  func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, HTTPURLResponse) {
    recordedRequests.append(.init(request: request, body: bodyData))
    return responses.removeFirst()
  }
}

final class MockProcessRunner: ProcessRunning, @unchecked Sendable {
  var result = ProcessResult(exitCode: 0, stdout: "", stderr: "")
  var executable = ""
  var arguments: [String] = []

  func run(executable: String, arguments: [String]) async throws -> ProcessResult {
    self.executable = executable
    self.arguments = arguments
    return result
  }
}

final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
  var values: [String: String] = [:]

  func readCredential(providerID: UUID, name: String) throws -> String? {
    values["\(providerID.uuidString):\(name)"]
  }

  func saveCredential(_ value: String, providerID: UUID, name: String) throws {
    values["\(providerID.uuidString):\(name)"] = value
  }

  func deleteCredential(providerID: UUID, name: String) throws {
    values.removeValue(forKey: "\(providerID.uuidString):\(name)")
  }
}

struct FixedImageReader: ClipboardImageReading {
  var image: ClipboardImage

  func readImage() throws -> ClipboardImage {
    image
  }
}

final class RecordingLinkWriter: ClipboardLinkWriting, @unchecked Sendable {
  var values: [String] = []

  func copy(_ value: String) {
    values.append(value)
  }
}

func httpResponse(url: String = "https://example.com", status: Int = 200) -> HTTPURLResponse {
  HTTPURLResponse(url: URL(string: url)!, statusCode: status, httpVersion: nil, headerFields: nil)!
}

func samplePNGData() -> Data {
  let image = NSImage(size: NSSize(width: 2, height: 2))
  image.lockFocus()
  NSColor.systemBlue.setFill()
  NSRect(x: 0, y: 0, width: 2, height: 2).fill()
  image.unlockFocus()
  return image.droppiePNGData()!
}
