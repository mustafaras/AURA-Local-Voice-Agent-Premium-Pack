import AuraCore
import AuraPolicy
import AuraShell
import AuraVSCode
import Foundation
import Testing

extension AuraVSCodeTests {
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
}
