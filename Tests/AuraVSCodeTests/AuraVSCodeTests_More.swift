import AuraCore
import AuraPolicy
import AuraSecurity
import AuraShell
import AuraVSCode
import Foundation
import Testing

/// Deterministic in-memory `SecretStoring` for the VS Code bridge secret store
/// so tests never touch the real Keychain.
private actor InMemorySecretStore: SecretStoring {
  private var values: [String: Data] = [:]

  func store(_ value: Data, forKey key: String) async throws(AuraError) {
    values[key] = value
  }

  func retrieve(forKey key: String) async throws(AuraError) -> Data? {
    values[key]
  }

  func delete(forKey key: String) async throws(AuraError) {
    values.removeValue(forKey: key)
  }
}

extension AuraVSCodeTests {
  // MARK: - SP-012 secret store provisioning/revocation round trip

  @Test("secret store provisions, retrieves, and revokes a per-extension secret")
  func secretStoreRoundTrip() async throws {
    let store = VSCodeBridgeSecretStore(
      secretStore: InMemorySecretStore(), serviceName: "ai.aura.vscode-bridge")
    let extensionID = "ai.aura.vscode-bridge"
    let secret = Data("test-only-16-char-secret".utf8)

    // Not provisioned yet.
    #expect(try await store.retrieveSecret(forExtensionID: extensionID) == nil)

    try await store.provision(sharedSecret: secret, forExtensionID: extensionID)
    #expect(try await store.retrieveSecret(forExtensionID: extensionID) == secret)

    // Revoking removes the secret; a second retrieve reports not provisioned.
    try await store.revoke(extensionID: extensionID)
    #expect(try await store.retrieveSecret(forExtensionID: extensionID) == nil)
  }

  @Test("secret store scopes secrets per extension identity")
  func secretStoreScopesPerExtension() async throws {
    let store = VSCodeBridgeSecretStore(
      secretStore: InMemorySecretStore(), serviceName: "ai.aura.vscode-bridge")
    let a = Data("secret-for-extension-a".utf8)
    let b = Data("secret-for-extension-b".utf8)

    try await store.provision(sharedSecret: a, forExtensionID: "ext-a")
    try await store.provision(sharedSecret: b, forExtensionID: "ext-b")

    #expect(try await store.retrieveSecret(forExtensionID: "ext-a") == a)
    #expect(try await store.retrieveSecret(forExtensionID: "ext-b") == b)

    // Revoking ext-a leaves ext-b intact.
    try await store.revoke(extensionID: "ext-a")
    #expect(try await store.retrieveSecret(forExtensionID: "ext-a") == nil)
    #expect(try await store.retrieveSecret(forExtensionID: "ext-b") == b)
  }

  @Test("secret store rejects an empty extension ID and empty secret")
  func secretStoreRejectsInvalidInput() async throws {
    let store = VSCodeBridgeSecretStore(
      secretStore: InMemorySecretStore(), serviceName: "ai.aura.vscode-bridge")

    await #expect(throws: AuraError.self) {
      try await store.provision(sharedSecret: Data("x".utf8), forExtensionID: "")
    }
    await #expect(throws: AuraError.self) {
      try await store.provision(sharedSecret: Data(), forExtensionID: "ext")
    }
    await #expect(throws: AuraError.self) {
      try await store.retrieveSecret(forExtensionID: "")
    }
    await #expect(throws: AuraError.self) {
      try await store.revoke(extensionID: "")
    }
  }
  @Test("authenticated bridge command envelope binds the typed command and request nonce")
  func authenticatedBridgeCommandEnvelope() throws {
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: "test-only-secret")
    let command = VSCodeBridgeCommand.runTask(name: "test", workspacePath: "/tmp")
    let envelope = try authenticator.makeCommandEnvelope(
      command: command,
      extensionID: "ai.aura.vscode-bridge",
      nonce: "request-1")
    try authenticator.validate(
      envelope,
      expectedExtensionID: "ai.aura.vscode-bridge")
    #expect(envelope.payload.command == command)

    let result = VSCodeBridgeCommandResult(outcome: .completed, message: "ok")
    let response = try authenticator.makeResponseEnvelope(
      result: result,
      extensionID: "ai.aura.vscode-bridge",
      requestNonce: "request-1",
      nonce: "response-1")
    try authenticator.validate(
      response,
      expectedExtensionID: "ai.aura.vscode-bridge",
      expectedRequestNonce: "request-1")
  }

  @Test("static bridge exposes typed command results without a raw command escape hatch")
  func staticBridgeTypedCommand() async throws {
    let command = VSCodeBridgeCommand.runTask(name: "build", workspacePath: "/tmp")
    let bridge = VSCodeStaticBridge(
      commandResults: [
        command: VSCodeBridgeCommandResult(outcome: .accepted, message: "task accepted")
      ])
    let result = try await bridge.execute(command)
    #expect(result.outcome == .accepted)
    #expect(result.message == "task accepted")
  }

  // MARK: - Workspace resolution

  @Test("workspace resolver follows explicit, active, durable, then candidate precedence")
  func workspaceResolverPrecedence() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let active = root.appendingPathComponent("active")
    let durable = root.appendingPathComponent("durable")
    try FileManager.default.createDirectory(at: active, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: durable, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let resolver = VSCodeWorkspaceResolver()
    let activeInfo = VSCodeWorkspaceInfo(folderPaths: [active.path])
    let explicit = resolver.resolve(
      explicitTarget: durable.path,
      activeWorkspace: activeInfo,
      activeDurableTaskPath: active.path,
      projectCandidates: [root.path])
    #expect(explicit.status == .resolved)
    #expect(explicit.source == .explicitUserTarget)
    #expect(explicit.path == durable.resolvingSymlinksInPath().path)
  }

  @Test("workspace resolver marks multiple candidates ambiguous")
  func workspaceResolverAmbiguous() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    let first = root.appendingPathComponent("one")
    let second = root.appendingPathComponent("two")
    try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let resolution = VSCodeWorkspaceResolver().resolve(
      explicitTarget: nil,
      activeWorkspace: VSCodeWorkspaceInfo(),
      activeDurableTaskPath: nil,
      projectCandidates: [first.path, second.path])
    #expect(resolution.status == .ambiguous)
    #expect(resolution.requiresConfirmation == true)
    #expect(resolution.path == nil)
    #expect(resolution.candidates.count == 2)
  }

  // MARK: - Dirty editor confirmation

  @Test("AlwaysDeny confirmation rejects")
  func alwaysDenyRejects() async {
    let confirmation = VSCodeAlwaysDenyConfirmation()
    let allowed = await confirmation.confirm(filePaths: ["/tmp/main.swift"], reason: "test")
    #expect(allowed == false)
  }

  @Test("AlwaysAllow confirmation allows")
  func alwaysAllowAllows() async {
    let confirmation = VSCodeAlwaysAllowConfirmation()
    let allowed = await confirmation.confirm(filePaths: ["/tmp/main.swift"], reason: "test")
    #expect(allowed == true)
  }

  // MARK: - Adapter state

  @Test("adapter activeWorkspace reads bridge editor state")
  func adapterActiveWorkspace() async {
    let editor = VSCodeEditorState(
      activeFilePath: "/tmp/main.swift",
      workspaceFolderPaths: ["/tmp"]
    )
    let bridge = VSCodeStaticBridge(editor: editor, terminal: nil, diagnostics: [])
    let adapter = VSCodeAdapter(
      configuration: AuraConfiguration.mock.vscode,
      shell: AuraShell(configuration: AuraConfiguration.mock.shell),
      bridge: bridge,
      confirmation: VSCodeAlwaysAllowConfirmation()
    )
    let info = await adapter.activeWorkspace()
    #expect(info.folderPaths == ["/tmp"])
  }

  @Test("adapter fails closed when PolicyEngine denies an action")
  func adapterFailsClosedWhenPolicyDenies() async throws {
    let policy = try await PolicyEngine(
      configuration: PolicyConfiguration(),
      eventBus: .shared)
    let adapter = VSCodeAdapter(
      configuration: AuraConfiguration.mock.vscode,
      shell: AuraShell(configuration: AuraConfiguration.mock.shell),
      bridge: VSCodeStaticBridge(),
      policyEngine: policy,
      confirmation: VSCodeAlwaysAllowConfirmation())
    let result = await adapter.execute(
      .openFile(path: "/tmp/blocked.swift", line: nil, column: nil, waitForClose: false),
      actor: testActor,
      correlationID: UUID().uuidString)
    guard case .failure(.permissionDenied) = result else {
      Issue.record("VS Code action did not fail closed on a denied policy decision")
      return
    }
  }

  @Test("adapter fails closed when policy requires confirmation")
  func adapterFailsClosedWhenPolicyRequiresConfirmation() async throws {
    let policy = try await PolicyEngine(
      configuration: PolicyConfiguration(denyByDefaultTiers: []),
      eventBus: .shared)
    let adapter = VSCodeAdapter(
      configuration: AuraConfiguration.mock.vscode,
      shell: AuraShell(configuration: AuraConfiguration.mock.shell),
      bridge: VSCodeStaticBridge(),
      policyEngine: policy,
      confirmation: VSCodeAlwaysAllowConfirmation())
    let command = VSCodeCommand.terminalCommand(
      command: AuraShellCommand(executable: "/bin/echo", arguments: ["should-not-run"]),
      workingDirectory: "/tmp",
      shell: "/bin/zsh")
    let result = await adapter.execute(
      command,
      actor: testActor,
      correlationID: UUID().uuidString)
    guard case .failure(.permissionDenied) = result else {
      Issue.record("VS Code mutation reached execution without confirmation")
      return
    }
  }

  // MARK: - Bridge health/availability mapping

  @Test("bridge health disconnected maps to disabled availability")
  func bridgeDisconnectedIsDisabled() async throws {
    let bridge = VSCodeStaticBridge(
      health: VSCodeBridgeHealth(state: .disconnected, detail: "no extension state file"))
    let adapter = VSCodeAdapter(
      configuration: AuraConfiguration.mock.vscode,
      shell: AuraShell(configuration: AuraConfiguration.mock.shell),
      bridge: bridge,
      confirmation: VSCodeAlwaysAllowConfirmation())
    let health = await adapter.bridgeHealth()
    #expect(health.state == .disconnected)
  }

  @Test("bridge health version mismatch maps to disabled availability")
  func bridgeVersionMismatchIsDisabled() async throws {
    let bridge = VSCodeStaticBridge(
      health: VSCodeBridgeHealth(state: .versionMismatch, detail: "protocol 2 vs expected 1"))
    let adapter = VSCodeAdapter(
      configuration: AuraConfiguration.mock.vscode,
      shell: AuraShell(configuration: AuraConfiguration.mock.shell),
      bridge: bridge,
      confirmation: VSCodeAlwaysAllowConfirmation())
    let health = await adapter.bridgeHealth()
    #expect(health.state == .versionMismatch)
  }

  // MARK: - Authenticator lifecycle

  @Test("authenticator rejects empty shared secret")
  func authenticatorRejectsEmptySecret() {
    #expect(throws: AuraError.self) {
      try VSCodeBridgeAuthenticator(sharedSecret: "")
    }
  }

  @Test("authenticator fails tampered response envelope")
  func authenticatorDetectsTamperedResponse() throws {
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: "tamper-test")
    let result = VSCodeBridgeCommandResult(outcome: .completed, message: "ok")
    var response = try authenticator.makeResponseEnvelope(
      result: result,
      extensionID: "ai.aura.vscode-bridge",
      requestNonce: "req-1",
      nonce: "resp-1")
    response = VSCodeBridgeResponseEnvelope(
      payload: response.payload,
      authenticationTag: "dGFtcGVyZWQ=")
    #expect(throws: AuraError.self) {
      try authenticator.validate(
        response,
        expectedExtensionID: "ai.aura.vscode-bridge",
        expectedRequestNonce: "req-1")
    }
  }

  // MARK: - Dirty editor + confirmation integration

  @Test("adapter denies dirty editor command when confirmation denies")
  func adapterDeniesDirtyEditor() async throws {
    let editor = VSCodeEditorState(
      activeFilePath: "/tmp/unsaved.swift",
      isDirty: true,
      workspaceFolderPaths: ["/tmp"])
    let bridge = VSCodeStaticBridge(editor: editor)
    let shell = AuraShell(configuration: AuraConfiguration.mock.shell)
    let adapter = VSCodeAdapter(
      configuration: VSCodeConfiguration(
        cliPath: "/fake/code",
        requireDirtyEditorConfirmation: true),
      shell: shell,
      bridge: bridge,
      policyEngine: nil,
      confirmation: VSCodeAlwaysDenyConfirmation())
    let result = await adapter.execute(
      .openFile(path: "/tmp/unsaved.swift", line: nil, column: nil, waitForClose: false),
      actor: testActor,
      correlationID: "dirty-editor-1")
    guard case .failure(let error) = result else {
      Issue.record("expected failure for denied dirty editor")
      return
    }
    let message = error.localizedDescription
    #expect(message.contains("dirty editor confirmation denied"))
  }

  @Test("adapter allows dirty editor command when confirmation allows")
  func adapterAllowsDirtyEditor() async throws {
    let editor = VSCodeEditorState(
      activeFilePath: "/tmp/unsaved.swift",
      isDirty: true,
      workspaceFolderPaths: ["/tmp"])
    let bridge = VSCodeStaticBridge(editor: editor)
    let shell = AuraShell(configuration: AuraConfiguration.mock.shell)
    let adapter = VSCodeAdapter(
      configuration: VSCodeConfiguration(
        cliPath: "/fake/code",
        requireDirtyEditorConfirmation: true),
      shell: shell,
      bridge: bridge,
      policyEngine: nil,
      confirmation: VSCodeAlwaysAllowConfirmation())
    let result = await adapter.execute(
      .openFile(path: "/tmp/unsaved.swift", line: nil, column: nil, waitForClose: false),
      actor: testActor,
      correlationID: "dirty-editor-2")
    // With policyEngine: nil, authorization always fails before CLI is invoked,
    // so the success path cannot be exercised without a permissive policy.
    guard case .failure(let error) = result else {
      Issue.record("expected failure because no policy engine authorizes the action")
      return
    }
    #expect(error.localizedDescription.contains("not authorized by PolicyEngine"))
  }
}
