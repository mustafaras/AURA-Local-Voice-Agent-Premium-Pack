import AuraCore
import Foundation

/// A minimal typed PTY abstraction for interactive shell sessions.
///
/// `PTYSession` wraps `Process` with a pseudo-terminal, supporting typed
/// input and streaming output. By default it runs the user's configured shell
/// and exposes read/write file handles rather than raw strings.
public actor PTYSession {
  public enum State: String, Sendable, Equatable {
    case idle
    case running
    case terminated
  }

  public let sessionID: UUID
  public let shell: String
  public let workingDirectory: String?
  public let environment: [String: String]

  private var process: Process?
  private var primaryFileHandle: FileHandle?
  private(set) public var state: State = .idle
  private var outputBuffer: [String] = []

  public init(
    shell: String = "/bin/zsh",
    workingDirectory: String? = nil,
    environment: [String: String] = [:]
  ) {
    self.sessionID = UUID()
    self.shell = shell
    self.workingDirectory = workingDirectory
    self.environment = environment
  }

  /// Start the PTY session and return the primary file handle.
  public func start() async throws(AuraError) {
    guard state == .idle else {
      throw AuraError.shellError("PTY session \(sessionID) is not idle")
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = ["-i"]
    if let cwd = workingDirectory {
      process.currentDirectoryURL = URL(fileURLWithPath: cwd)
    }
    process.environment = environment.isEmpty ? ProcessInfo.processInfo.environment : environment

    let (primary, secondary) = createPseudoTerminalPair()
    process.standardInput = secondary
    process.standardOutput = secondary
    process.standardError = secondary
    secondary.closeFile()

    do {
      try process.run()
    } catch {
      primary.closeFile()
      throw AuraError.shellError("PTY launch failed: \(error.localizedDescription)")
    }

    self.process = process
    self.primaryFileHandle = primary
    self.state = .running

    Task {
      await drainOutput(primary: primary)
    }
  }

  /// Write a line of input to the PTY primary endpoint.
  public func send(line: String) throws(AuraError) {
    guard state == .running, let primary = primaryFileHandle else {
      throw AuraError.shellError("PTY session \(sessionID) is not running")
    }
    guard let data = (line + "\n").data(using: .utf8) else {
      throw AuraError.shellError("could not encode PTY input")
    }
    primary.write(data)
  }

  /// Read currently buffered output lines and clear the buffer.
  public func readBufferedOutput() async -> [String] {
    let snapshot = outputBuffer
    outputBuffer.removeAll(keepingCapacity: true)
    return snapshot
  }

  /// Terminate the PTY session.
  public func terminate() async {
    process?.terminate()
    primaryFileHandle?.closeFile()
    state = .terminated
  }

  private func drainOutput(primary: FileHandle) async {
    primary.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard let text = String(data: data, encoding: .utf8) else { return }
      Task { [weak self] in
        await self?.appendOutput(text)
      }
    }
  }

  private func appendOutput(_ text: String) {
    outputBuffer.append(text)
  }
}

private func createPseudoTerminalPair() -> (primary: FileHandle, secondary: FileHandle) {
  var primaryFD: Int32 = 0
  var secondaryFD: Int32 = 0
  let result = openpty(
    &primaryFD,
    &secondaryFD,
    nil,
    nil,
    nil
  )
  guard result == 0 else {
    fatalError("openpty failed with errno \(errno)")
  }
  return (
    FileHandle(fileDescriptor: primaryFD, closeOnDealloc: true),
    FileHandle(fileDescriptor: secondaryFD, closeOnDealloc: true)
  )
}
