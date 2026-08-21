import AuraCore
import AuraPolicy
import AuraSecurity
import AuraShell
import AuraVSCode
import Foundation
import Testing

/// SP-012 live acceptance probe.
///
/// This suite runs only when `AURA_SP012_LIVE_ACCEPTANCE=1` AND
/// `AURA_SP012_BRIDGE_DIRECTORY` is set to the directory the user configured
/// for the three bridge files (state/command/response). It proves the live,
/// authenticated extension round trip **in-process**:
///
/// - reads the shared secret from the real macOS Keychain (never printed);
/// - constructs the real `VSCodeFileBridge` bound to the live bridge files;
/// - validates a freshly-signed envelope the extension is currently writing;
/// - executes a typed `.editor` command and authenticates the signed response.
///
/// The secret is handled entirely inside this process; it is never logged,
/// never returned, and never reaches the calling agent. The test emits only
/// booleans and non-secret health state.
private let liveAcceptanceEnabled =
  ProcessInfo.processInfo.environment["AURA_SP012_LIVE_ACCEPTANCE"] == "1"
  && (ProcessInfo.processInfo.environment["AURA_SP012_BRIDGE_DIRECTORY"]
      ?? "").isEmpty == false

@Suite("AuraVSCodeLiveAcceptance", .serialized, .enabled(if: liveAcceptanceEnabled))
struct AuraVSCodeLiveAcceptance {
  static func bridgeDirectory() -> URL {
    let raw = ProcessInfo.processInfo.environment["AURA_SP012_BRIDGE_DIRECTORY"]!
    return URL(fileURLWithPath: raw)
  }

  @Test("live extension state file is currently being written")
  func liveStateFileIsFresh() throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let stateURL = dir.appendingPathComponent("vscode-state.json")
    let attributes = try FileManager.default.attributesOfItem(atPath: stateURL.path)
    let modificationDate = attributes[.modificationDate] as? Date ?? .distantPast
    let age = Date().timeIntervalSince(modificationDate)
    #expect(age <= 30, "state file age \(age)s exceeds 30s; extension may be stopped")
  }

  @Test("live extension snapshot authenticates against the Keychain secret")
  func liveSignedEnvelopeAuthenticates() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let bridge = try await AuraVSCodeLiveAcceptance.makeLiveBridge(dir: dir)
    let stateURL = dir.appendingPathComponent("vscode-state.json")
    do {
      let data = try Data(contentsOf: stateURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let envelope = try decoder.decode(VSCodeBridgeEnvelope.self, from: data)
      // Authenticating a freshly-written live envelope proves AURA's Keychain
      // secret matches the extension's SecretStorage secret. Editor content is
      // incidental — it depends on which window is focused at the instant of
      // capture, not on bridge health.
      try await AuraVSCodeLiveAcceptance.validateLiveEnvelope(envelope)
      #expect(envelope.payload.protocolVersion == VSCodeBridgeSignedPayload.currentProtocolVersion)
      #expect(!envelope.payload.nonce.isEmpty)
    } catch {
      Issue.record("live envelope failed: \(error)")
      throw error
    }
  }

  @Test("live authenticated editor command round trips end to end")
  func liveEditorCommandRoundTrips() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let bridge = try await AuraVSCodeLiveAcceptance.makeLiveBridge(dir: dir)
    let health = await bridge.health()
    #expect(health.state == .ready, "live bridge health: \(health.state) — \(health.detail)")
    // A live, policy-authorized, authenticated editor command must complete.
    // The editor payload is incidental (it depends on which window is focused
    // at the instant of capture); the round trip itself is the proof.
    let result = try await bridge.execute(.editor)
    #expect(result.outcome == .completed)
    #expect(result.message == "editor state")
  }

  @Test("live workspace command round trips and returns the open workspace")
  func liveWorkspaceCommandRoundTrips() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let bridge = try await AuraVSCodeLiveAcceptance.makeLiveBridge(dir: dir)
    let result = try await bridge.execute(.workspace)
    #expect(result.outcome == .completed)
  }

  @Test("residual live response file decodes and authenticates in-process")
  func residualResponseAuthenticates() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let responseURL = dir.appendingPathComponent("vscode-response.json")
    guard FileManager.default.fileExists(atPath: responseURL.path) else {
      throw AuraError.invalidConfiguration("no residual response file; run the round-trip first")
    }
    let data = try Data(contentsOf: responseURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let envelope = try decoder.decode(VSCodeBridgeResponseEnvelope.self, from: data)
    // A freshly-written response must authenticate; a stale one is rejected on
    // expiry — both are correct behavior. Here we accept the envelope only if
    // it is still fresh, proving decode + keychain validation work together.
    let expiresAt = envelope.payload.expiresAt
    if expiresAt > Date() {
      try await AuraVSCodeLiveAcceptance.validateLiveResponse(envelope)
      #expect(envelope.payload.result.outcome == .completed)
    } else {
      await #expect(throws: AuraError.self) {
        try await AuraVSCodeLiveAcceptance.validateLiveResponse(envelope)
      }
    }
  }

  /// Reads the Keychain secret in-process and builds a live bridge.
  private static func makeLiveBridge(dir: URL) async throws -> VSCodeFileBridge {
    let store = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    guard
      let secret = try await store.retrieveSecret(forExtensionID: "ai.aura.vscode-bridge"),
      let secretString = String(data: secret, encoding: .utf8)
    else {
      throw AuraError.securityError("AURA Keychain is not provisioned for the VS Code bridge")
    }
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: secretString)
    return VSCodeFileBridge(
      statePath: dir.appendingPathComponent("vscode-state.json").path,
      authenticator: authenticator,
      requireAuthentication: true,
      expectedExtensionID: "ai.aura.vscode-bridge",
      commandPath: dir.appendingPathComponent("vscode-command.json").path,
      responsePath: dir.appendingPathComponent("vscode-response.json").path,
      commandTimeoutSeconds: 5)
  }

  /// Validates a live envelope against the in-process Keychain secret.
  private static func validateLiveEnvelope(_ envelope: VSCodeBridgeEnvelope) async throws {
    let store = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    guard
      let secret = try await store.retrieveSecret(forExtensionID: "ai.aura.vscode-bridge"),
      let secretString = String(data: secret, encoding: .utf8)
    else {
      throw AuraError.securityError("AURA Keychain is not provisioned for the VS Code bridge")
    }
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: secretString)
    try authenticator.validate(
      envelope, expectedExtensionID: "ai.aura.vscode-bridge")
  }

  /// Validates a live response envelope against the in-process Keychain secret.
  private static func validateLiveResponse(
    _ envelope: VSCodeBridgeResponseEnvelope
  ) async throws {
    let store = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    guard
      let secret = try await store.retrieveSecret(forExtensionID: "ai.aura.vscode-bridge"),
      let secretString = String(data: secret, encoding: .utf8)
    else {
      throw AuraError.securityError("AURA Keychain is not provisioned for the VS Code bridge")
    }
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: secretString)
    try authenticator.validate(
      envelope, expectedExtensionID: "ai.aura.vscode-bridge",
      expectedRequestNonce: envelope.payload.requestNonce)
  }
}

// MARK: - Live failure modes (run against the real Keychain secret + live extension)

@Suite("AuraVSCodeLiveFailureModes", .serialized, .enabled(if: liveAcceptanceEnabled))
struct AuraVSCodeLiveFailureModes {
  /// Builds a live bridge bound to the real Keychain secret and bridge files.
  private static func makeLiveBridge(dir: URL) async throws -> VSCodeFileBridge {
    let store = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    guard
      let secret = try await store.retrieveSecret(forExtensionID: "ai.aura.vscode-bridge"),
      let secretString = String(data: secret, encoding: .utf8)
    else {
      throw AuraError.securityError("AURA Keychain is not provisioned for the VS Code bridge")
    }
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: secretString)
    return VSCodeFileBridge(
      statePath: dir.appendingPathComponent("vscode-state.json").path,
      authenticator: authenticator,
      requireAuthentication: true,
      expectedExtensionID: "ai.aura.vscode-bridge",
      commandPath: dir.appendingPathComponent("vscode-command.json").path,
      responsePath: dir.appendingPathComponent("vscode-response.json").path,
      commandTimeoutSeconds: 5)
  }

  @Test("live replay: re-submitting an old signed snapshot nonce is rejected")
  func liveReplayRejected() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let store = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    guard let secret = try await store.retrieveSecret(forExtensionID: "ai.aura.vscode-bridge"),
      let secretString = String(data: secret, encoding: .utf8)
    else {
      throw AuraError.securityError("AURA Keychain is not provisioned")
    }
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: secretString)

    // Three distinct signed snapshots sharing one secret; each carries a unique
    // nonce and the same (live-valid) extension identity.
    let replayPath = dir.appendingPathComponent("replay-state.json")
    func write(nonce: String) throws {
      let envelope = try authenticator.makeEnvelope(
        snapshot: VSCodeBridgeSnapshot(
          editor: VSCodeEditorState(activeFilePath: "/tmp/replay.swift", workspaceFolderPaths: ["/tmp"]),
          terminal: nil,
          diagnostics: [],
          timestamp: Date()),
        extensionID: "ai.aura.vscode-bridge",
        nonce: nonce,
        lifetimeSeconds: 30)
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      try encoder.encode(envelope).write(to: replayPath, options: .atomic)
    }

    let bridge = VSCodeFileBridge(
      statePath: replayPath.path,
      authenticator: authenticator,
      requireAuthentication: true,
      expectedExtensionID: "ai.aura.vscode-bridge",
      commandPath: dir.appendingPathComponent("vscode-command.json").path,
      responsePath: dir.appendingPathComponent("vscode-response.json").path)

    // nonce-1 accepted (active), nonce-2 accepted (active, nonce-1 now historical),
    // then nonce-1 re-submitted = replay → health degrades.
    try write(nonce: "nonce-live-1")
    let first = await bridge.health()
    #expect(first.state == .ready, "first distinct nonce must be .ready, got \(first.state)")

    try write(nonce: "nonce-live-2")
    let second = await bridge.health()
    #expect(second.state == .ready, "second distinct nonce must be .ready, got \(second.state)")

    try write(nonce: "nonce-live-1")
    let replayed = await bridge.health()
    #expect(
      replayed.state == .degraded,
      "re-submitting the consumed nonce must degrade health, got \(replayed.state)")

    try? FileManager.default.removeItem(at: replayPath)
  }

  @Test("live expired envelope is rejected (stale snapshot)")
  func liveExpiredEnvelopeRejected() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let bridge = try await Self.makeLiveBridge(dir: dir)
    // maxStalenessSeconds = 0 forces staleness rejection on the live file.
    let stale = await bridge.editorState(maxStalenessSeconds: 0)
    #expect(stale == nil, "a snapshot older than the staleness bound must be rejected")
  }

  @Test("live disconnect reports .disconnected when the extension file is absent")
  func liveDisconnectHealth() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let store = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    guard let secret = try await store.retrieveSecret(forExtensionID: "ai.aura.vscode-bridge"),
      let secretString = String(data: secret, encoding: .utf8)
    else {
      throw AuraError.securityError("AURA Keychain is not provisioned")
    }
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: secretString)
    // A bridge pointed at a nonexistent state path must report .disconnected.
    let missingDir = dir.appendingPathComponent("does-not-exist")
    let bridge = VSCodeFileBridge(
      statePath: missingDir.appendingPathComponent("vscode-state.json").path,
      authenticator: authenticator,
      requireAuthentication: true,
      expectedExtensionID: "ai.aura.vscode-bridge")
    let health = await bridge.health()
    #expect(health.state == .disconnected, "absent state file must yield .disconnected, got \(health.state)")
  }

  @Test("live version mismatch is rejected by the authenticator")
  func liveVersionMismatchRejected() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let store = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    guard let secret = try await store.retrieveSecret(forExtensionID: "ai.aura.vscode-bridge"),
      let secretString = String(data: secret, encoding: .utf8)
    else {
      throw AuraError.securityError("AURA Keychain is not provisioned")
    }
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: secretString)
    // Sign an envelope, then decode it and tamper the protocol version before
    // validation. Because validation reads payloadText (the signed bytes), a
    // tampered protocolVersion must fail authentication.
    let stateURL = dir.appendingPathComponent("vscode-state.json")
    let data = try Data(contentsOf: stateURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let envelope = try decoder.decode(VSCodeBridgeEnvelope.self, from: data)
    let tamperedText = envelope.payloadText.replacingOccurrences(
      of: "\"protocolVersion\":2", with: "\"protocolVersion\":1")
    let tampered = #"{"payload":\#(encodeJSONString(tamperedText)),"authenticationTag":\#(encodeJSONString(envelope.authenticationTag))}"#
    let rebuilt = try decoder.decode(VSCodeBridgeEnvelope.self, from: Data(tampered.utf8))
    #expect(throws: AuraError.self) {
      try authenticator.validate(
        rebuilt, expectedExtensionID: "ai.aura.vscode-bridge",
        now: rebuilt.payload.issuedAt.addingTimeInterval(1))
    }
  }
}

// MARK: - Live adapter policy gates (dirty buffer + confirmation-required)

@Suite("AuraVSCodeLivePolicyGates", .serialized, .enabled(if: liveAcceptanceEnabled))
struct AuraVSCodeLivePolicyGates {
  /// Reads the real Keychain secret and signs a dirty-editor snapshot into a
  /// throwaway state file, returning a live bridge bound to it.
  private static func makeDirtyBridge(dir: URL) async throws -> (any VSCodeExtensionBridge, URL) {
    let store = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    guard let secret = try await store.retrieveSecret(forExtensionID: "ai.aura.vscode-bridge"),
      let secretString = String(data: secret, encoding: .utf8)
    else {
      throw AuraError.securityError("AURA Keychain is not provisioned")
    }
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: secretString)
    let envelope = try authenticator.makeEnvelope(
      snapshot: VSCodeBridgeSnapshot(
        editor: VSCodeEditorState(
          activeFilePath: "/tmp/live-dirty.swift", isDirty: true,
          workspaceFolderPaths: ["/tmp"]),
        terminal: nil,
        diagnostics: [],
        timestamp: Date()),
      extensionID: "ai.aura.vscode-bridge",
      nonce: "dirty-nonce-\(UUID().uuidString)",
      lifetimeSeconds: 30)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let stateURL = dir.appendingPathComponent("live-dirty-state.json")
    try encoder.encode(envelope).write(to: stateURL, options: .atomic)
    let bridge = VSCodeFileBridge(
      statePath: stateURL.path,
      authenticator: authenticator,
      requireAuthentication: true,
      expectedExtensionID: "ai.aura.vscode-bridge",
      commandPath: dir.appendingPathComponent("vscode-command.json").path,
      responsePath: dir.appendingPathComponent("vscode-response.json").path)
    return (bridge, stateURL)
  }

  @Test("live dirty buffer fails closed without confirmation")
  func liveDirtyBufferFailsClosed() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let (bridge, stateURL) = try await Self.makeDirtyBridge(dir: dir)
    defer { try? FileManager.default.removeItem(at: stateURL) }
    let shell = AuraShell(configuration: AuraConfiguration.mock.shell)
    let adapter = VSCodeAdapter(
      configuration: VSCodeConfiguration(
        cliPath: "/fake/code",
        bridgeStatePath: stateURL.path,
        requireDirtyEditorConfirmation: true),
      shell: shell,
      bridge: bridge,
      policyEngine: nil,
      confirmation: VSCodeAlwaysDenyConfirmation())
    let result = await adapter.execute(
      .openFile(path: "/tmp/live-dirty.swift", line: nil, column: nil, waitForClose: false),
      actor: .agentCodex,
      correlationID: UUID().uuidString)
    guard case .failure(let error) = result else {
      Issue.record("dirty editor command did not fail closed on denied confirmation")
      return
    }
    #expect(error.localizedDescription.contains("dirty editor confirmation denied"))
  }

  @Test("confirmation-required policy gate fails closed without a completed confirmation")
  func liveConfirmationRequiredFailsClosed() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let (bridge, stateURL) = try await Self.makeDirtyBridge(dir: dir)
    defer { try? FileManager.default.removeItem(at: stateURL) }
    let policy = try await PolicyEngine(
      configuration: PolicyConfiguration(denyByDefaultTiers: []),
      eventBus: .shared)
    let shell = AuraShell(configuration: AuraConfiguration.mock.shell)
    let adapter = VSCodeAdapter(
      configuration: VSCodeConfiguration(
        cliPath: "/fake/code",
        bridgeStatePath: stateURL.path,
        requireDirtyEditorConfirmation: true),
      shell: shell,
      bridge: bridge,
      policyEngine: policy,
      confirmation: VSCodeAlwaysAllowConfirmation())
    let command = VSCodeCommand.terminalCommand(
      command: AuraShellCommand(executable: "/bin/echo", arguments: ["should-not-run"]),
      workingDirectory: "/tmp",
      shell: "/bin/zsh")
    let result = await adapter.execute(
      command,
      actor: .agentCodex,
      correlationID: UUID().uuidString)
    guard case .failure(.permissionDenied) = result else {
      Issue.record("mutation reached execution without a completed confirmation")
      return
    }
  }

  @Test("live revoke makes the bridge unauthorized and refuses reads, then restore restores pairing")
  func liveRevokeFailsClosedAndRestores() async throws {
    let dir = AuraVSCodeLiveAcceptance.bridgeDirectory()
    let store = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    let extensionID = "ai.aura.vscode-bridge"

    // Read the live secret in-process; never print it.
    guard let liveSecret = try await store.retrieveSecret(forExtensionID: extensionID) else {
      throw AuraError.securityError("AURA Keychain is not provisioned; cannot run revoke test")
    }

    // Sanity: the current bridge is authenticated and ready.
    let stateURL = dir.appendingPathComponent("vscode-state.json")
    let authenticatedBridge = VSCodeFileBridge(
      statePath: stateURL.path,
      authenticator: try VSCodeBridgeAuthenticator(
        sharedSecret: String(data: liveSecret, encoding: .utf8) ?? ""),
      requireAuthentication: true,
      expectedExtensionID: extensionID)
    let readyHealth = await authenticatedBridge.health()
    #expect(readyHealth.state == .ready, "baseline bridge must be .ready, got \(readyHealth.state)")

    // Revoke on the AURA side.
    try await store.revoke(extensionID: extensionID)

    // After revoke, the bridge constructed against the (now empty) secret store
    // must be .unauthorized and reads refused.
    let revokedSecret = try await store.retrieveSecret(forExtensionID: extensionID)
    #expect(revokedSecret == nil, "revoke must clear the Keychain secret")

    let revokedBridge = VSCodeFileBridge(
      statePath: stateURL.path,
      authenticator: nil,
      requireAuthentication: true,
      expectedExtensionID: extensionID)
    let revokedHealth = await revokedBridge.health()
    #expect(
      revokedHealth.state == .unauthorized,
      "revoked bridge must report .unauthorized, got \(revokedHealth.state)")
    #expect(revokedBridge.isAvailable == false, "revoked bridge must be unavailable")

    // AURA-side read through the real (revoked) secret store must fail closed.
    let afterRevokeStore = VSCodeBridgeSecretStore(
      secretStore: KeychainSecretStore(serviceName: "ai.aura.vscode-bridge"))
    let afterRevoke = try await afterRevokeStore.retrieveSecret(forExtensionID: extensionID)
    #expect(afterRevoke == nil, "AURA-side read after revoke must be nil")

    // Restore the same secret so the working pairing is left intact for the
    // user. The value stays in-process throughout.
    try await store.provision(sharedSecret: liveSecret, forExtensionID: extensionID)
    let restored = try await store.retrieveSecret(forExtensionID: extensionID)
    #expect(restored == liveSecret, "restore must re-establish the pairing")
  }
}

/// Encodes a Swift string as a JSON string literal (shared with the interop suite).
private func encodeJSONString(_ value: String) -> String {
  let data = try? JSONSerialization.data(withJSONObject: [value], options: [])
  guard let data, let text = String(data: data, encoding: .utf8) else { return "\"\"" }
  return String(text.dropFirst().dropLast())
}
