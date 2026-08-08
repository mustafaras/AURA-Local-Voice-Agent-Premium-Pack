import AuraCore
import Foundation

import struct AuraShell.Command

// MARK: - Re-exported AuraShell types used by public API

/// Alias for `AuraShell.Command` to avoid module-name collision when used as
/// an associated value type in a public `AuraVSCode` enum.
public typealias AuraShellCommand = Command

// MARK: - VS Code typed command values

/// A typed, policy-ready request to control Visual Studio Code.
///
/// `VSCodeCommand` never contains a raw shell string. Tool adapters translate
/// model intents into these values; the `VSCodeAdapter` turns them into typed
/// `AuraShell.Command` invocations.
public enum VSCodeCommand: Sendable, Equatable {
  /// Open a workspace file (`.code-workspace`).
  case openWorkspace(path: String, newWindow: Bool)

  /// Open a folder in VS Code.
  case openFolder(path: String, newWindow: Bool, addToWorkspace: Bool)

  /// Open a file at an optional line and column.
  case openFile(path: String, line: Int?, column: Int?, waitForClose: Bool)

  /// Open a diff between two files.
  case openDiff(left: String, right: String)

  /// Add a folder to the current multi-root workspace.
  case addFolder(path: String)

  /// Install, uninstall, or update an extension.
  case manageExtension(extensionID: String, action: ExtensionAction)

  /// Run a VS Code task by name (via CLI `--`).
  case runTask(name: String, workspacePath: String?)

  /// Run tests in the current workspace (via CLI extension command if available,
  /// otherwise falls back to terminal test command).
  case runTests(target: String?, workspacePath: String?)

  /// Inject a typed shell command into the integrated terminal.
  case terminalCommand(
    command: AuraShellCommand,
    workingDirectory: String,
    shell: String
  )

  /// Open the VS Code agents panel.
  case openAgents

  public enum ExtensionAction: String, Sendable, Equatable, Codable {
    case install
    case uninstall
    case update
  }
}

/// A single VS Code diagnostic reported by the extension bridge.
public struct VSCodeDiagnostic: Codable, Sendable, Equatable {
  public let filePath: String
  public let line: Int
  public let column: Int
  public let severity: VSCodeDiagnosticsEvent.Severity
  public let message: String
  public let source: String?

  public init(
    filePath: String,
    line: Int,
    column: Int,
    severity: VSCodeDiagnosticsEvent.Severity,
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

// MARK: - VS Code editor state

/// Snapshot of editor state supplied by the extension bridge or by parsing CLI
/// output where possible.
public struct VSCodeEditorState: Codable, Sendable, Equatable {
  public let activeFilePath: String?
  public let languageID: String?
  public let isDirty: Bool
  public let workspaceFolderPaths: [String]

  public init(
    activeFilePath: String? = nil,
    languageID: String? = nil,
    isDirty: Bool = false,
    workspaceFolderPaths: [String] = []
  ) {
    self.activeFilePath = activeFilePath
    self.languageID = languageID
    self.isDirty = isDirty
    self.workspaceFolderPaths = workspaceFolderPaths
  }
}

// MARK: - VS Code terminal state

/// Snapshot of an integrated terminal supplied by the extension bridge.
public struct VSCodeTerminalState: Codable, Sendable, Equatable {
  public let terminalID: String?
  public let shell: String
  public let workingDirectory: String

  public init(
    terminalID: String? = nil,
    shell: String,
    workingDirectory: String
  ) {
    self.terminalID = terminalID
    self.shell = shell
    self.workingDirectory = workingDirectory
  }
}

// MARK: - Workspace detection result

/// Result of detecting the currently active VS Code workspace.
public struct VSCodeWorkspaceInfo: Codable, Sendable, Equatable {
  public let workspaceFilePath: String?
  public let folderPaths: [String]
  public let activeFolderPath: String?

  public init(
    workspaceFilePath: String? = nil,
    folderPaths: [String] = [],
    activeFolderPath: String? = nil
  ) {
    self.workspaceFilePath = workspaceFilePath
    self.folderPaths = folderPaths
    self.activeFolderPath = activeFolderPath
  }
}
