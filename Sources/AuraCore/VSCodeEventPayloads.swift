import Foundation

// MARK: - VS Code lifecycle and state event payloads

/// Emitted when VS Code is asked to open a workspace, folder, file, or diff.
public struct VSCodeOpenRequestEvent: EventPayload {
  public static let eventType = "vscode.open.requested"

  public enum Target: String, Codable, Sendable, Equatable {
    case workspace
    case folder
    case file
    case diff
  }

  public let target: Target
  public let path: String
  public let line: Int?
  public let column: Int?
  public let newWindow: Bool
  public let waitForClose: Bool

  public init(
    target: Target,
    path: String,
    line: Int? = nil,
    column: Int? = nil,
    newWindow: Bool = false,
    waitForClose: Bool = false
  ) {
    self.target = target
    self.path = path
    self.line = line
    self.column = column
    self.newWindow = newWindow
    self.waitForClose = waitForClose
  }
}

/// Emitted when VS Code reports an editor state change.
public struct VSCodeEditorStateEvent: EventPayload {
  public static let eventType = "vscode.editor.state"

  public let activeFilePath: String?
  public let languageID: String?
  public let isDirty: Bool
  public let workspaceFolderPaths: [String]
  public let timestamp: TimeInterval

  public init(
    activeFilePath: String? = nil,
    languageID: String? = nil,
    isDirty: Bool = false,
    workspaceFolderPaths: [String] = [],
    timestamp: TimeInterval = Date().timeIntervalSince1970
  ) {
    self.activeFilePath = activeFilePath
    self.languageID = languageID
    self.isDirty = isDirty
    self.workspaceFolderPaths = workspaceFolderPaths
    self.timestamp = timestamp
  }
}

/// Emitted when a terminal command is injected into the VS Code integrated terminal.
public struct VSCodeTerminalCommandEvent: EventPayload {
  public static let eventType = "vscode.terminal.command"

  public let terminalID: String?
  public let shell: String
  public let workingDirectory: String
  public let commandExecutable: String
  public let commandArguments: [String]
  public let verified: Bool

  public init(
    terminalID: String? = nil,
    shell: String,
    workingDirectory: String,
    commandExecutable: String,
    commandArguments: [String],
    verified: Bool
  ) {
    self.terminalID = terminalID
    self.shell = shell
    self.workingDirectory = workingDirectory
    self.commandExecutable = commandExecutable
    self.commandArguments = commandArguments
    self.verified = verified
  }
}

/// Emitted when diagnostics are reported by the extension bridge.
public struct VSCodeDiagnosticsEvent: EventPayload {
  public static let eventType = "vscode.diagnostics"

  public enum Severity: String, Codable, Sendable, Equatable {
    case error
    case warning
    case information
    case hint
  }

  public struct Diagnostic: Codable, Sendable, Equatable {
    public let filePath: String
    public let line: Int
    public let column: Int
    public let severity: Severity
    public let message: String
    public let source: String?

    public init(
      filePath: String,
      line: Int,
      column: Int,
      severity: Severity,
      message: String,
      source: String? = nil
    ) {
      self.filePath = filePath
      self.line = line
      self.column = column
      self.severity = severity
      self.message = message
      self.source = source
    }
  }

  public let diagnostics: [Diagnostic]
  public let timestamp: TimeInterval

  public init(
    diagnostics: [Diagnostic],
    timestamp: TimeInterval = Date().timeIntervalSince1970
  ) {
    self.diagnostics = diagnostics
    self.timestamp = timestamp
  }
}

/// Emitted when a request requires user confirmation because of dirty editors.
public struct VSCodeDirtyEditorConfirmationEvent: EventPayload {
  public static let eventType = "vscode.dirty.confirmation"

  public let reason: String
  public let confirmed: Bool
  public let filePaths: [String]

  public init(
    reason: String,
    confirmed: Bool,
    filePaths: [String]
  ) {
    self.reason = reason
    self.confirmed = confirmed
    self.filePaths = filePaths
  }
}

/// Emitted when the extension bridge status changes.
public struct VSCodeExtensionBridgeStatusEvent: EventPayload {
  public static let eventType = "vscode.bridge.status"

  public enum Status: String, Codable, Sendable, Equatable {
    case connected
    case disconnected
    case stale
    case unsupported
  }

  public let status: Status
  public let extensionID: String?
  public let lastSeenAt: TimeInterval?

  public init(
    status: Status,
    extensionID: String? = nil,
    lastSeenAt: TimeInterval? = nil
  ) {
    self.status = status
    self.extensionID = extensionID
    self.lastSeenAt = lastSeenAt
  }
}
