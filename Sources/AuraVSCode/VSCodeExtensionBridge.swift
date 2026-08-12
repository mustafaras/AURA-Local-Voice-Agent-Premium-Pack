import AuraCore
import Foundation

/// Abstraction over the companion VS Code extension that writes editor,
/// terminal, and diagnostics state to a JSON file.
///
/// A live bridge reads the file written by the extension. Tests and fallback
/// paths use the `Static` implementation.
public protocol VSCodeExtensionBridge: Sendable {
  /// Read current editor state, if available.
  func editorState(maxStalenessSeconds: Double) async -> VSCodeEditorState?

  /// Read current active terminal state, if available.
  func terminalState(maxStalenessSeconds: Double) async -> VSCodeTerminalState?

  /// Read current workspace diagnostics, if available.
  func diagnostics(maxStalenessSeconds: Double) async -> [VSCodeDiagnostic]

  /// Execute one enumerated, authenticated bridge command.
  func execute(_ command: VSCodeBridgeCommand) async throws(AuraError)
    -> VSCodeBridgeCommandResult

  /// Return current bridge/extension health without guessing that a state file
  /// alone proves command readiness.
  func health() async -> VSCodeBridgeHealth

  /// Whether the bridge can be reached on this system.
  var isAvailable: Bool { get }
}

/// File-based bridge that reads JSON state emitted by the companion extension.
public actor VSCodeFileBridge: VSCodeExtensionBridge {
  let statePath: String?
  let authenticator: VSCodeBridgeAuthenticator?
  let requireAuthentication: Bool
  let expectedExtensionID: String?
  let maxPayloadBytes: Int
  let commandPath: String?
  let responsePath: String?
  let commandTimeoutSeconds: Double
  var activeNonce: String?
  var acceptedNonces: Set<String> = []

  public init(
    statePath: String?,
    authenticator: VSCodeBridgeAuthenticator? = nil,
    requireAuthentication: Bool = true,
    expectedExtensionID: String? = nil,
    maxPayloadBytes: Int = 1_000_000,
    commandPath: String? = nil,
    responsePath: String? = nil,
    commandTimeoutSeconds: Double = 5
  ) {
    self.statePath = statePath
    self.authenticator = authenticator
    self.requireAuthentication = requireAuthentication
    self.expectedExtensionID = expectedExtensionID
    self.maxPayloadBytes = maxPayloadBytes
    let stateURL = statePath.map(URL.init(fileURLWithPath:))
    self.commandPath =
      commandPath
      ?? stateURL?.deletingLastPathComponent()
      .appendingPathComponent("vscode-command.json").path
    self.responsePath =
      responsePath
      ?? stateURL?.deletingLastPathComponent()
      .appendingPathComponent("vscode-response.json").path
    self.commandTimeoutSeconds = commandTimeoutSeconds
  }

  nonisolated public var isAvailable: Bool {
    guard let path = statePath else { return false }
    guard FileManager.default.fileExists(atPath: path) else { return false }
    return !requireAuthentication || authenticator != nil
  }

  public func editorState(maxStalenessSeconds: Double) async -> VSCodeEditorState? {
    try? snapshot(maxStalenessSeconds: maxStalenessSeconds).editor
  }

  public func terminalState(maxStalenessSeconds: Double) async -> VSCodeTerminalState? {
    try? snapshot(maxStalenessSeconds: maxStalenessSeconds).terminal
  }

  public func diagnostics(maxStalenessSeconds: Double) async -> [VSCodeDiagnostic] {
    (try? snapshot(maxStalenessSeconds: maxStalenessSeconds).diagnostics) ?? []
  }

  public func health() async -> VSCodeBridgeHealth {
    guard requireAuthentication else {
      return VSCodeBridgeHealth(
        state: .degraded,
        detail: "legacy unauthenticated snapshot mode is enabled; commands are disabled")
    }
    guard authenticator != nil else {
      return VSCodeBridgeHealth(
        state: .unauthorized,
        detail: "shared-secret authentication is not configured")
    }
    guard let statePath, FileManager.default.fileExists(atPath: statePath) else {
      return VSCodeBridgeHealth(
        state: .disconnected,
        detail: "authenticated extension state file is unavailable")
    }
    guard (try? snapshot(maxStalenessSeconds: 30)) != nil else {
      return VSCodeBridgeHealth(
        state: .degraded,
        detail: "authenticated extension state is stale or invalid")
    }
    return VSCodeBridgeHealth(
      state: .ready,
      extensionID: expectedExtensionID,
      detail: "authenticated extension snapshot is available")
  }

  private func snapshot(maxStalenessSeconds: Double) throws -> VSCodeBridgeSnapshot {
    guard let path = statePath else {
      throw AuraError.invalidConfiguration("extension bridge state path is nil")
    }
    let url = URL(fileURLWithPath: path)
    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    let modificationDate = attributes[.modificationDate] as? Date ?? Date.distantPast
    let age = Date().timeIntervalSince(modificationDate)
    guard age <= maxStalenessSeconds else {
      throw AuraError.invalidConfiguration("extension bridge state is stale (age \(age)s)")
    }
    let data = try Data(contentsOf: url)
    guard data.count <= maxPayloadBytes else {
      throw AuraError.securityError("VS Code bridge payload exceeds configured limit")
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if requireAuthentication {
      guard let authenticator else {
        throw AuraError.securityError("VS Code bridge authentication is not configured")
      }
      let envelope = try decoder.decode(VSCodeBridgeEnvelope.self, from: data)
      try authenticator.validate(
        envelope,
        expectedExtensionID: expectedExtensionID
      )
      try accept(nonce: envelope.payload.nonce)
      return envelope.payload.snapshot
    }
    return try decoder.decode(VSCodeBridgeSnapshot.self, from: data)
  }

  func validate(command: VSCodeBridgeCommand) throws(AuraError) {
    switch command.kind {
    case .runTask:
      guard let name = command.name, !name.isEmpty else {
        throw AuraError.invalidConfiguration("VS Code runTask requires a non-empty task name")
      }
    case .cancelTask:
      guard let taskID = command.taskID, !taskID.isEmpty else {
        throw AuraError.invalidConfiguration("VS Code cancelTask requires a task ID")
      }
    case .cancelTests:
      guard let testID = command.testID, !testID.isEmpty else {
        throw AuraError.invalidConfiguration("VS Code cancelTests requires a test ID")
      }
    case .runTests, .health, .workspace, .editor, .diagnostics, .tasks, .tests, .terminalSessions:
      break
    }
  }

  func accept(nonce: String) throws(AuraError) {
    if activeNonce == nonce {
      return
    }
    guard !acceptedNonces.contains(nonce) else {
      throw AuraError.securityError("VS Code bridge nonce replay detected")
    }
    acceptedNonces.insert(nonce)
    activeNonce = nonce
    if acceptedNonces.count > 128, let oldest = acceptedNonces.first {
      acceptedNonces.remove(oldest)
    }
  }
}

struct BridgeExecutionContext: Sendable {
  let authenticator: VSCodeBridgeAuthenticator
  let extensionID: String
  let commandPath: String
  let responsePath: String
  let timeoutSeconds: Double
}

struct BridgeResponseContext: Sendable {
  let responsePath: String
  let extensionID: String
  let requestNonce: String
  let timeoutSeconds: Double
  let authenticator: VSCodeBridgeAuthenticator
}

/// Static bridge for tests or headless fallback.
public struct VSCodeStaticBridge: VSCodeExtensionBridge {
  public let editor: VSCodeEditorState?
  public let terminal: VSCodeTerminalState?
  public let diagnostics: [VSCodeDiagnostic]
  public let bridgeHealth: VSCodeBridgeHealth
  public let commandResults: [VSCodeBridgeCommand: VSCodeBridgeCommandResult]
  public var isAvailable: Bool { true }

  public init(
    editor: VSCodeEditorState? = nil,
    terminal: VSCodeTerminalState? = nil,
    diagnostics: [VSCodeDiagnostic] = [],
    health: VSCodeBridgeHealth? = nil,
    commandResults: [VSCodeBridgeCommand: VSCodeBridgeCommandResult] = [:]
  ) {
    self.editor = editor
    self.terminal = terminal
    self.diagnostics = diagnostics
    self.bridgeHealth = health ?? VSCodeBridgeHealth(state: .ready, detail: "static test bridge")
    self.commandResults = commandResults
  }

  public func editorState(maxStalenessSeconds: Double) async -> VSCodeEditorState? { editor }
  public func terminalState(maxStalenessSeconds: Double) async -> VSCodeTerminalState? { terminal }
  public func diagnostics(maxStalenessSeconds: Double) async -> [VSCodeDiagnostic] { diagnostics }
  public func health() async -> VSCodeBridgeHealth { bridgeHealth }

  public func execute(_ command: VSCodeBridgeCommand) async throws(AuraError)
    -> VSCodeBridgeCommandResult
  {
    if let result = commandResults[command] {
      return result
    }
    switch command.kind {
    case .health:
      return VSCodeBridgeCommandResult(
        outcome: .completed, message: bridgeHealth.detail, health: bridgeHealth)
    case .workspace:
      return VSCodeBridgeCommandResult(
        outcome: .completed,
        message: "static workspace state",
        health: bridgeHealth,
        workspace: VSCodeWorkspaceInfo(folderPaths: editor?.workspaceFolderPaths ?? []))
    case .editor:
      return VSCodeBridgeCommandResult(
        outcome: .completed, message: "static editor state", health: bridgeHealth, editor: editor)
    case .diagnostics:
      return VSCodeBridgeCommandResult(
        outcome: .completed,
        message: "static diagnostics",
        health: bridgeHealth,
        diagnostics: diagnostics)
    case .tasks, .tests, .terminalSessions:
      return VSCodeBridgeCommandResult(
        outcome: .completed, message: "static bridge state", health: bridgeHealth)
    case .runTask, .cancelTask, .runTests, .cancelTests:
      return VSCodeBridgeCommandResult(
        outcome: .unavailable,
        message: "static bridge has no configured command result",
        health: bridgeHealth)
    }
  }
}

// MARK: - Bridge DTO

/// Internal shape of the JSON file written by the companion extension.
public struct VSCodeBridgeSnapshot: Codable, Sendable, Equatable {
  public let editor: VSCodeEditorState?
  public let terminal: VSCodeTerminalState?
  public let diagnostics: [VSCodeDiagnostic]
  public let timestamp: Date?

  public init(
    editor: VSCodeEditorState? = nil,
    terminal: VSCodeTerminalState? = nil,
    diagnostics: [VSCodeDiagnostic] = [],
    timestamp: Date? = nil
  ) {
    self.editor = editor
    self.terminal = terminal
    self.diagnostics = diagnostics
    self.timestamp = timestamp
  }
}
