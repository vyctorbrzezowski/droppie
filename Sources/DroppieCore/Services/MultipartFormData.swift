import Foundation

public struct MultipartFormData: Sendable {
  public var body: Data
  public var contentType: String

  public init(parts: [Part], boundary: String = "DroppieBoundary-\(UUID().uuidString)") {
    var data = Data()

    for part in parts {
      data.append("--\(boundary)\r\n")
      data.append("Content-Disposition: form-data; name=\"\(part.name)\"")
      if let fileName = part.fileName {
        data.append("; filename=\"\(fileName)\"")
      }
      data.append("\r\n")
      data.append("Content-Type: \(part.contentType)\r\n\r\n")
      data.append(part.data)
      data.append("\r\n")
    }

    data.append("--\(boundary)--\r\n")
    self.body = data
    self.contentType = "multipart/form-data; boundary=\(boundary)"
  }

  public struct Part: Sendable {
    public var name: String
    public var fileName: String?
    public var contentType: String
    public var data: Data

    public init(name: String, fileName: String? = nil, contentType: String = "text/plain", data: Data) {
      self.name = name
      self.fileName = fileName
      self.contentType = contentType
      self.data = data
    }
  }
}

private extension Data {
  mutating func append(_ string: String) {
    append(Data(string.utf8))
  }
}
