import AuraCore
import Foundation

// MARK: - Authenticated automation helper client

/// A typed, authenticated client for the sandboxed automation helper.
///
/// This is the least-privilege execution boundary for app-lifecycle operations:
/// the main process sends a typed, authenticated, capability-scoped
/// `AutomationHelperOperation` to the sandboxed `AuraAutomationHelper`, which
/// executes it and returns a typed `AutomationHelperResult`. The helper holds
/// no model, network, secret, or UI authority beyond the app-lifecycle operation
/// named in the request.
public actor AuthenticatedAutomationHelperClient {
  private let client: HelperIPCClient

  public init(
    executableURL: URL,
    expectedSHA256Hex: String,
    designatedRequirement: String,
    sharedSecret: Data,
    peerVerifier: any HelperIPCPeerVerifying = SecCodeHelperIPCPeerVerifier()
  ) throws(AuraError) {
    self.client = try HelperIPCClient(
      helperKind: .automation,
      executableURL: executableURL,
      expectedSHA256Hex: expectedSHA256Hex,
      designatedRequirement: designatedRequirement,
      sharedSecret: sharedSecret,
      peerVerifier: peerVerifier)
  }

  /// Execute a typed app-lifecycle operation through the sandboxed helper.
  public func execute(
    operation: AutomationHelperOperation,
    actor: ActorID,
    issuedAt: Date = Date()
  ) async throws(AuraError) -> AutomationHelperResult {
    let capability: Capability
    switch operation {
    case .launch, .activate, .hide:
      capability = Capability(domain: "app", action: "lifecycle", riskTier: .reversible)
    case .quit:
      capability = Capability(domain: "app", action: "terminate", riskTier: .mutation)
    }
    let target = PolicyTarget(appID: bundleIdentifier(for: operation))
    return try await client.execute(
      capability: capability,
      actor: actor,
      target: target,
      payload: operation,
      issuedAt: issuedAt)
  }

  private func bundleIdentifier(for operation: AutomationHelperOperation) -> String? {
    switch operation {
    case .launch(let id), .activate(let id), .hide(let id), .quit(let id):
      return id
    }
  }
}
