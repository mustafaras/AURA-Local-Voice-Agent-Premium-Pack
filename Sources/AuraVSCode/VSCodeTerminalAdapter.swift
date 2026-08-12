import AuraCore
import AuraShell
import Foundation

/// Injects commands into the VS Code integrated terminal after verifying shell
/// and working directory.
///
/// Verification is performed against a `VSCodeExtensionBridge`. If the bridge
/// is unavailable and `requireVerification` is `true`, the adapter refuses to
/// inject. When `requireVerification` is `false`, it falls back to a typed shell
/// command in the user-configured working directory.
public actor VSCodeTerminalAdapter {
  private let configuration: VSCodeConfiguration
  private let shell: AuraShell
  private let bridge: any VSCodeExtensionBridge

  public init(
    configuration: VSCodeConfiguration,
    shell: AuraShell,
    bridge: any VSCodeExtensionBridge
  ) {
    self.configuration = configuration
    self.shell = shell
    self.bridge = bridge
  }

  /// Inject `command` into the integrated terminal.
  ///
  /// - Returns: `.failure` if verification fails or if the shell is not in the
  ///   allowlist.
  public func inject(
    _ command: VSCodeCommand,
    actor: ActorID,
    correlationID: String
  ) async -> Result<String, AuraError> {
    guard case .terminalCommand(let typedCommand, let workingDirectory, let shellPath) = command
    else {
      return .failure(
        AuraError.invalidConfiguration("VSCodeTerminalAdapter only handles .terminalCommand"))
    }

    do {
      try configuration.validate()
    } catch {
      return .failure(error)
    }

    let terminal = await bridge.terminalState(
      maxStalenessSeconds: configuration.bridgeMaxStalenessSeconds)
    switch verifyTerminal(
      terminal: terminal,
      workingDirectory: workingDirectory,
      shellPath: shellPath
    ) {
    case .failure(let error): return .failure(error)
    case .success(let verified):
      let executionID = UUID(uuidString: correlationID) ?? UUID()
      let shellCommand = Command(
        executable: shellPath,
        arguments: ["-c", typedCommand.executable] + typedCommand.arguments,
        workingDirectory: workingDirectory,
        timeoutSeconds: typedCommand.timeoutSeconds,
        expectedExitCodes: typedCommand.expectedExitCodes,
        riskTier: .mutation,
        ptyRequested: true
      )

      let result = await shell.execute(
        command: shellCommand,
        actor: actor,
        sessionID: executionID,
        correlationID: executionID,
        causationID: executionID
      )
      await emitTerminalEvent(
        TerminalEventContext(
          terminal: terminal,
          typedCommand: typedCommand,
          shellPath: shellPath,
          workingDirectory: workingDirectory,
          verified: verified,
          executionID: executionID,
          actor: actor)
      )
      return terminalResult(result)
    }
  }

  private func verifyTerminal(
    terminal: VSCodeTerminalState?,
    workingDirectory: String,
    shellPath: String
  ) -> Result<Bool, AuraError> {
    guard configuration.requireTerminalVerification else { return .success(false) }
    guard let terminal else {
      return .failure(
        AuraError.invalidConfiguration(
          "VS Code terminal state unavailable; cannot verify shell/cwd"))
    }
    guard configuration.allowedTerminalShells.contains(terminal.shell) else {
      return .failure(
        AuraError.invalidConfiguration("terminal shell \(terminal.shell) is not allowed"))
    }
    guard
      terminal.workingDirectory == workingDirectory
        || workingDirectory.hasPrefix(terminal.workingDirectory)
    else {
      return .failure(
        AuraError.invalidConfiguration(
          "requested cwd \(workingDirectory) does not match terminal cwd "
            + "\(terminal.workingDirectory)"))
    }
    guard terminal.shell == shellPath else {
      return .failure(
        AuraError.invalidConfiguration(
          "requested shell \(shellPath) does not match terminal shell "
            + "\(terminal.shell)"))
    }
    return .success(true)
  }

  private func emitTerminalEvent(
    _ context: TerminalEventContext
  ) async {
    let event = VSCodeTerminalCommandEvent(
      terminalID: context.terminal?.terminalID,
      shell: context.shellPath,
      workingDirectory: context.workingDirectory,
      commandExecutable: context.typedCommand.executable,
      commandArguments: context.typedCommand.arguments,
      verified: context.verified
    )
    await AuraEventBus.shared.emit(
      EventEnvelope(
        correlationID: context.executionID,
        causationID: context.executionID,
        actor: context.actor,
        sensitivity: .internalLevel,
        payload: event
      )
    )
  }

  private func terminalResult(
    _ result: Result<ProcessResult, AuraError>
  ) -> Result<String, AuraError> {
    switch result {
    case .success(let processResult):
      let combined = [processResult.stdout, processResult.stderr]
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return .success(combined)
    case .failure(let error): return .failure(error)
    }
  }
}

private struct TerminalEventContext: Sendable {
  let terminal: VSCodeTerminalState?
  let typedCommand: Command
  let shellPath: String
  let workingDirectory: String
  let verified: Bool
  let executionID: UUID
  let actor: ActorID
}
