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
  private var masterFileHandle: FileHandle?
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

  /// Start the PTY session and return the master file handle.
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

    let (master, slave) = createPseudoTerminalPair()
    process.standardInput = slave
    process.standardOutput = slave
    process.standardError = slave
    slave.closeFile()

    do {
      try process.run()
    } catch {
      master.closeFile()
      throw AuraError.shellError("PTY launch failed: \(error.localizedDescription)")
    }

    self.process = process
    self.masterFileHandle = master
    self.state = .running

    Task {
      await drainOutput(master: master)
    }
  }

  /// Write a line of input to the PTY master.
  public func send(line: String) throws(AuraError) {
    guard state == .running, let master = masterFileHandle else {
      throw AuraError.shellError("PTY session \(sessionID) is not running")
    }
    guard let data = (line + "\n").data(using: .utf8) else {
      throw AuraError.shellError("could not encode PTY input")
    }
    master.write(data)
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
    masterFileHandle?.closeFile()
    state = .terminated
  }

  private func drainOutput(master: FileHandle) async {
    master.readabilityHandler = { [weak self] handle in
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

private func createPseudoTerminalPair() -> (master: FileHandle, slave: FileHandle) {
  var masterFD: Int32 = 0
  var slaveFD: Int32 = 0
  let result = openpty(
    &masterFD,
    &slaveFD,
    nil,
    nil,
    nil
  )
  guard result == 0 else {
    fatalError("openpty failed with errno \(errno)")
  }
  return (
    FileHandle(fileDescriptor: masterFD, closeOnDealloc: true),
    FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)
  )
}
