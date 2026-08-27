import AuraCore
import Foundation

// MARK: - Authenticated shell helper client

/// A typed, authenticated client for the sandboxed shell helper.
///
/// This is the least-privilege execution boundary for shell commands: the main
/// process no longer executes arbitrary commands itself when the helper is
/// configured; instead it sends a typed, authenticated, capability-scoped
/// `Command` to the sandboxed `AuraShellHelper`, which validates and executes
/// it and returns a typed `ProcessResult`. The helper holds no model, network,
/// secret, or UI authority — only the ability to run a validated command within
/// its sandbox.
public actor AuthenticatedShellHelperClient {
  private let client: HelperIPCClient
  private let configuration: ShellConfiguration

  public init(
    executableURL: URL,
    expectedSHA256Hex: String,
    designatedRequirement: String,
    sharedSecret: Data,
    configuration: ShellConfiguration,
    peerVerifier: any HelperIPCPeerVerifying = SecCodeHelperIPCPeerVerifier()
  ) throws(AuraError) {
    self.configuration = configuration
    self.client = try HelperIPCClient(
      helperKind: .shell,
      executableURL: executableURL,
      expectedSHA256Hex: expectedSHA256Hex,
      designatedRequirement: designatedRequirement,
      sharedSecret: sharedSecret,
      peerVerifier: peerVerifier)
  }

  /// Execute a typed command through the sandboxed helper.
  ///
  /// The command is validated locally first (fail fast), then sent to the
  /// helper which validates it again before execution. The response is a typed
  /// `ProcessResult` bound to the request's nonce and authenticated.
  public func execute(
    command: Command,
    actor: ActorID,
    issuedAt: Date = Date()
  ) async throws(AuraError) -> ProcessResult {
    try command.validate(configuration: configuration)
    return try await client.execute(
      capability: .shellExec,
      actor: actor,
      target: PolicyTarget(
        command: command.executable,
        arguments: command.arguments,
        environmentKeys: Array(command.environment.keys)),
      payload: command,
      issuedAt: issuedAt)
  }
}
