import Foundation

public struct ProcessResult: Equatable, Sendable {
  public var exitCode: Int32
  public var stdout: String
  public var stderr: String

  public init(exitCode: Int32, stdout: String, stderr: String) {
    self.exitCode = exitCode
    self.stdout = stdout
    self.stderr = stderr
  }
}

public protocol ProcessRunning: Sendable {
  func run(executable: String, arguments: [String]) async throws -> ProcessResult
}

public final class ProcessRunner: ProcessRunning {
  public init() {}

  public func run(executable: String, arguments: [String]) async throws -> ProcessResult {
    try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: executable)
      process.arguments = arguments

      let stdout = Pipe()
      let stderr = Pipe()
      process.standardOutput = stdout
      process.standardError = stderr

      process.terminationHandler = { process in
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        continuation.resume(returning: ProcessResult(
          exitCode: process.terminationStatus,
          stdout: String(data: outData, encoding: .utf8) ?? "",
          stderr: String(data: errData, encoding: .utf8) ?? ""
        ))
      }

      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}
