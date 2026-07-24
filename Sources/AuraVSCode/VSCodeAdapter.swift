import AuraCore
import AuraShell
import Foundation

// MARK: - Dirty editor confirmation provider

/// Pluggable confirmation gate for closing dirty editors. A real implementation
/// can surface a system dialog; tests provide a fixed value.
public protocol VSCodeDirtyEditorConfirmation: Sendable {
  /// Ask the user whether it is safe to proceed despite dirty editors.
  func confirm(filePaths: [String], reason: String) async -> Bool
}

/// Confirmation provider that always denies (safe default for headless tests).
public struct VSCodeAlwaysDenyConfirmation: VSCodeDirtyEditorConfirmation {
  public init() {}
  public func confirm(filePaths: [String], reason: String) async -> Bool { false }
}

/// Confirmation provider that always allows (for deterministic test fixtures).
public struct VSCodeAlwaysAllowConfirmation: VSCodeDirtyEditorConfirmation {
  public init() {}
  public func confirm(filePaths: [String], reason: String) async -> Bool { true }
}

// MARK: - Adapter coordinator

/// Public coordinator for the AURA VS Code adapter.
///
/// `VSCodeAdapter` turns model intents (`VSCodeCommand`) into policy requests,
/// CLI invocations, terminal injections, or extension-bridge operations. It never
/// executes raw model text and refuses to close dirty editors without
/// confirmation.
public actor VSCodeAdapter {
  private let configuration: VSCodeConfiguration
  private let policyAdapter: VSCodePolicyAdapter.Type
  private let cli: VSCodeCLI
  private let bridge: any VSCodeExtensionBridge
  private let terminalAdapter: VSCodeTerminalAdapter
  private let confirmation: any VSCodeDirtyEditorConfirmation

  public init(
    configuration: VSCodeConfiguration,
    shell: AuraShell,
    bridge: any VSCodeExtensionBridge,
    confirmation: any VSCodeDirtyEditorConfirmation = VSCodeAlwaysDenyConfirmation()
  ) {
    self.configuration = configuration
    self.policyAdapter = VSCodePolicyAdapter.self
    self.cli = VSCodeCLI(configuration: configuration, shell: shell)
    self.bridge = bridge
    self.terminalAdapter = VSCodeTerminalAdapter(
      configuration: configuration,
      shell: shell,
      bridge: bridge
    )
    self.confirmation = confirmation
  }

  /// Detect the active workspace from the extension bridge or CLI output.
  public func activeWorkspace(maxStalenessSeconds: Double? = nil) async -> VSCodeWorkspaceInfo {
    let staleness = maxStalenessSeconds ?? configuration.bridgeMaxStalenessSeconds
    if let editor = await bridge.editorState(maxStalenessSeconds: staleness) {
      return VSCodeWorkspaceInfo(
        workspaceFilePath: nil,
        folderPaths: editor.workspaceFolderPaths,
        activeFolderPath: editor.workspaceFolderPaths.first
      )
    }
    return VSCodeWorkspaceInfo()
  }

  /// Execute a typed VS Code command after optional dirty-editor safety checks.
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

    // Dirty-editor safety for commands that may close or replace editor state.
    if configuration.requireDirtyEditorConfirmation, command.mayCloseEditors {
      let editor = await bridge.editorState(
        maxStalenessSeconds: configuration.bridgeMaxStalenessSeconds)
      if let editor = editor, editor.isDirty {
        let confirmed = await confirmation.confirm(
          filePaths: editor.workspaceFolderPaths,
          reason: "VS Code command may close or replace dirty editor state"
        )
        let event = VSCodeDirtyEditorConfirmationEvent(
          reason: "dirty editor before \(command.kind)",
          confirmed: confirmed,
          filePaths: editor.workspaceFolderPaths
        )
        await emit(event, actor: actor, correlationID: correlationID)
        guard confirmed else {
          return .failure(AuraError.invalidConfiguration("dirty editor confirmation denied"))
        }
      }
    }

    // Policy request is constructed for every command, even though the current
    // boundary does not yet await a concrete PolicyEngine decision.
    let request = policyAdapter.request(
      for: command,
      actor: actor,
      correlationID: correlationID
    )
    await emit(
      VSCodePolicyEvaluationEvent(request: request),
      actor: actor,
      correlationID: correlationID
    )

    switch command {
    case .terminalCommand:
      return await terminalAdapter.inject(command, actor: actor, correlationID: correlationID)

    case .runTask, .runTests:
      // Tasks and tests require the extension bridge because the CLI has no
      // direct task/test runner flag.
      return await executeViaBridge(command, actor: actor, correlationID: correlationID)

    case .openAgents:
      return await cli.execute(command, actor: actor, correlationID: correlationID)

    default:
      return await cli.execute(command, actor: actor, correlationID: correlationID)
    }
  }

  /// Direct CLI invocation for commands that the `code` binary supports.
  public func executeCLI(
    _ command: VSCodeCommand,
    actor: ActorID,
    correlationID: String
  ) async -> Result<String, AuraError> {
    await cli.execute(command, actor: actor, correlationID: correlationID)
  }

  /// Read editor state from the extension bridge.
  public func editorState() async -> VSCodeEditorState? {
    await bridge.editorState(maxStalenessSeconds: configuration.bridgeMaxStalenessSeconds)
  }

  /// Read terminal state from the extension bridge.
  public func terminalState() async -> VSCodeTerminalState? {
    await bridge.terminalState(maxStalenessSeconds: configuration.bridgeMaxStalenessSeconds)
  }

  /// Read diagnostics from the extension bridge.
  public func diagnostics() async -> [VSCodeDiagnostic] {
    await bridge.diagnostics(maxStalenessSeconds: configuration.bridgeMaxStalenessSeconds)
  }

  // MARK: - Private

  private func executeViaBridge(
    _ command: VSCodeCommand,
    actor: ActorID,
    correlationID: String
  ) async -> Result<String, AuraError> {
    // The bridge itself cannot run commands; route to terminal injection with
    // a shell-safe representation. This is intentionally conservative.
    return .failure(
      AuraError.invalidConfiguration(
        "\(command.kind) requires the VS Code extension bridge terminal route"
      ))
  }

  private func emit(_ payload: some EventPayload, actor: ActorID, correlationID: String) async {
    let id = UUID(uuidString: correlationID) ?? UUID()
    let envelope = EventEnvelope(
      correlationID: id,
      causationID: id,
      actor: actor,
      sensitivity: .internalLevel,
      payload: payload
    )
    await AuraEventBus.shared.emit(envelope)
  }
}

// MARK: - Event payload for policy evaluation

public struct VSCodePolicyEvaluationEvent: EventPayload {
  public static let eventType = "vscode.policy.evaluation"

  public let request: PolicyEvaluationRequest

  public init(request: PolicyEvaluationRequest) {
    self.request = request
  }
}

// MARK: - Command helpers

extension VSCodeCommand {
  fileprivate var kind: String {
    switch self {
    case .openWorkspace: return "openWorkspace"
    case .openFolder: return "openFolder"
    case .openFile: return "openFile"
    case .openDiff: return "openDiff"
    case .addFolder: return "addFolder"
    case .manageExtension: return "manageExtension"
    case .runTask: return "runTask"
    case .runTests: return "runTests"
    case .terminalCommand: return "terminalCommand"
    case .openAgents: return "openAgents"
    }
  }

  fileprivate var mayCloseEditors: Bool {
    switch self {
    case .openWorkspace(_, let newWindow):
      return newWindow
    case .openFolder(_, let newWindow, _):
      return newWindow
    case .openFile:
      return true
    case .openDiff:
      return true
    default:
      return false
    }
  }
}
