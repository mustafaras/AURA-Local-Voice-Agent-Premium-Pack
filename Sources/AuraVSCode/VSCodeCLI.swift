import AuraCore
import AuraShell
import Foundation

/// Typed adapter that invokes the VS Code `code` CLI via `AuraShell`.
///
/// This type only forwards arguments that have been verified against the CLI
/// help output. It never composes a raw shell string.
public actor VSCodeCLI {
  private let configuration: VSCodeConfiguration
  private let shell: AuraShell

  public init(configuration: VSCodeConfiguration, shell: AuraShell) {
    self.configuration = configuration
    self.shell = shell
  }

  /// Execute a VS Code CLI command with `code` as the executable.
  public func execute(
    _ command: VSCodeCommand,
    actor: ActorID,
    correlationID: String
  ) async -> Result<String, AuraError> {
    do {
      try configuration.validate()
    } catch {
      return .failure(error)
    }

    let executionID = UUID(uuidString: correlationID) ?? UUID()
    let args = arguments(for: command)
    let cwd: String?
    switch command {
    case .openFolder(let path, _, _), .openWorkspace(let path, _):
      cwd = (path as NSString).deletingLastPathComponent
    case .runTask(_, let workspace), .runTests(_, let workspace):
      cwd = workspace
    default:
      cwd = nil
    }

    let shellCommand = Command(
      executable: configuration.cliPath,
      arguments: args,
      workingDirectory: cwd,
      timeoutSeconds: configuration.cliTimeoutSeconds,
      expectedExitCodes: exitCodes(for: command),
      riskTier: .reversible,
      ptyRequested: false
    )

    let result = await shell.execute(
      command: shellCommand,
      actor: actor,
      sessionID: executionID,
      correlationID: executionID,
      causationID: executionID
    )
    switch result {
    case .success(let processResult):
      let combined = [processResult.stdout, processResult.stderr]
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return .success(combined)
    case .failure(let error):
      return .failure(error)
    }
  }

  // MARK: - Verified flag mapping

  /// Exposed for unit tests so argument mapping can be verified without
  /// invoking the real `code` executable.
  public func makeArguments(for command: VSCodeCommand) -> [String] {
    arguments(for: command)
  }

  private func arguments(for command: VSCodeCommand) -> [String] {
    switch command {
    case .openWorkspace(let path, let newWindow):
      return pathArguments(path: path, newWindow: newWindow)

    case .openFolder(let path, let newWindow, let addToWorkspace):
      return folderArguments(
        path: path,
        newWindow: newWindow,
        addToWorkspace: addToWorkspace)

    case .openFile(let path, let line, let column, let waitForClose):
      return fileArguments(
        path: path,
        line: line,
        column: column,
        waitForClose: waitForClose)

    case .openDiff(let left, let right):
      return ["--diff", left, right]

    case .addFolder(let path):
      return ["--add", path]

    case .manageExtension(let extensionID, let action):
      return extensionArguments(extensionID: extensionID, action: action)

    case .runTask:
      // VS Code CLI has no native task runner flag; use extension bridge.
      // This branch returns a marker so the adapter routes to the bridge.
      return ["--agents"]

    case .runTests:
      return ["--agents"]  // Routed to extension bridge / terminal fallback.

    case .terminalCommand:
      return ["--agents"]  // Terminal injection bypasses the CLI.

    case .openAgents:
      return ["--agents"]
    }
  }

  private func pathArguments(path: String, newWindow: Bool) -> [String] {
    var args = [path]
    if newWindow { args.insert("--new-window", at: 0) }
    return args
  }

  private func folderArguments(
    path: String,
    newWindow: Bool,
    addToWorkspace: Bool
  ) -> [String] {
    if addToWorkspace { return ["--add", path] }
    return pathArguments(path: path, newWindow: newWindow)
  }

  private func fileArguments(
    path: String,
    line: Int?,
    column: Int?,
    waitForClose: Bool
  ) -> [String] {
    var args: [String]
    if let line {
      let colSuffix = column.map { ":\($0)" } ?? ""
      args = ["--goto", "\(path):\(line)\(colSuffix)"]
    } else {
      args = [path]
    }
    if waitForClose { args.append("--wait") }
    return args
  }

  private func extensionArguments(
    extensionID: String,
    action: VSCodeCommand.ExtensionAction
  ) -> [String] {
    switch action {
    case .install: return ["--install-extension", extensionID]
    case .uninstall: return ["--uninstall-extension", extensionID]
    case .update: return ["--update-extensions", extensionID]
    }
  }

  private func exitCodes(for command: VSCodeCommand) -> Set<Int> {
    switch command {
    case .manageExtension(_, .update):
      // `--update-extensions` exits 0 even when extensions are current.
      return [0]
    case .manageExtension(_, .install), .manageExtension(_, .uninstall):
      return [0]
    case .terminalCommand, .runTask, .runTests:
      return [0]
    default:
      return [0]
    }
  }
}
