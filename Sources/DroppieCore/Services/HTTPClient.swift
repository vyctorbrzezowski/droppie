import Foundation

public protocol HTTPClient: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
  func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, HTTPURLResponse)
}

public final class URLSessionHTTPClient: HTTPClient {
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw UploadError.invalidResponse("The server did not return an HTTP response.")
    }
    return (data, httpResponse)
  }

  public func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.upload(for: request, from: bodyData)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw UploadError.invalidResponse("The server did not return an HTTP response.")
    }
    return (data, httpResponse)
  }
}

public extension HTTPURLResponse {
  var droppieIsSuccess: Bool {
    (200...299).contains(statusCode)
  }
}
