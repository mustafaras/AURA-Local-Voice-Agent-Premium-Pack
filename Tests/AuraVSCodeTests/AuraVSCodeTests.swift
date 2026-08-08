import AuraCore
import AuraPolicy
import AuraShell
import AuraVSCode
import Foundation
import Testing

@Suite("AuraVSCode")
struct AuraVSCodeTests {
  private let testActor: ActorID = .agentCodex

  // MARK: - Policy mapping

  @Test("policyRequest maps openFile to vscodeOpen capability")
  func policyRequestOpenFile() {
    let request = VSCodePolicyAdapter.request(
      for: .openFile(path: "/tmp/main.swift", line: 10, column: 2, waitForClose: false),
      actor: testActor,
      correlationID: "open-file-1"
    )
    #expect(request.capability == Capability.vscodeOpen)
    #expect(request.actor == testActor)
    #expect(request.target.filePath == "/tmp/main.swift")
  }

  @Test("policyRequest maps terminalCommand to vscodeInjectTerminal")
  func policyRequestTerminalCommand() throws {
    let command = AuraShellCommand(
      executable: "/bin/echo",
      arguments: ["hello"]
    )
    let request = VSCodePolicyAdapter.request(
      for: .terminalCommand(
        command: command,
        workingDirectory: "/tmp",
        shell: "/bin/zsh"
      ),
      actor: testActor,
      correlationID: "term-1"
    )
    #expect(request.capability == Capability.vscodeInjectTerminal)
    #expect(request.target.command == "/bin/echo")
    #expect(request.target.arguments == ["hello"])
  }

  @Test("policyRequest maps manageExtension to vscodeManageExtension")
  func policyRequestManageExtension() {
    let request = VSCodePolicyAdapter.request(
      for: .manageExtension(
        extensionID: "ms-python.python",
        action: .install
      ),
      actor: testActor,
      correlationID: "ext-1"
    )
    #expect(request.capability == Capability.vscodeManageExtension)
    #expect(request.target.filePath == "ms-python.python")
    #expect(request.target.arguments == ["install"])
  }

  @Test("typed bridge task command maps to a dedicated reversible capability")
  func policyRequestBridgeTask() {
    let request = VSCodePolicyAdapter.request(
      for: VSCodeCommand.runTask(name: "build", workspacePath: "/tmp"),
      actor: testActor,
      correlationID: "bridge-task-1")
    #expect(request.capability == Capability.vscodeRunTask)
    #expect(request.target.filePath == "vscode-task://build")
  }

  private var testShell: AuraShell { AuraShell(configuration: AuraConfiguration.mock.shell) }

  // MARK: - CLI argument mapping

  @Test("CLI arguments for openFile include --goto with line and column")
  func cliArgumentsOpenFile() async {
    let cli = VSCodeCLI(configuration: AuraConfiguration.mock.vscode, shell: testShell)
    let command: VSCodeCommand = .openFile(
      path: "/tmp/main.swift", line: 12, column: 5, waitForClose: false)
    let args = await cli.makeArguments(for: command)
    #expect(args.contains("--goto"))
    #expect(args.contains("/tmp/main.swift:12:5"))
    #expect(!args.contains("--new-window"))
  }

  @Test("CLI arguments for openWorkspace include path")
  func cliArgumentsOpenWorkspace() async {
    let cli = VSCodeCLI(configuration: AuraConfiguration.mock.vscode, shell: testShell)
    let command: VSCodeCommand = .openWorkspace(path: "/tmp/aura.code-workspace", newWindow: false)
    let args = await cli.makeArguments(for: command)
    #expect(args.contains("/tmp/aura.code-workspace"))
    #expect(!args.contains("--new-window"))
  }

  @Test("CLI arguments for openWorkspace newWindow include --new-window")
  func cliArgumentsOpenWorkspaceNewWindow() async {
    let cli = VSCodeCLI(configuration: AuraConfiguration.mock.vscode, shell: testShell)
    let command: VSCodeCommand = .openWorkspace(path: "/tmp/aura.code-workspace", newWindow: true)
    let args = await cli.makeArguments(for: command)
    #expect(args.contains("--new-window"))
  }

  @Test("CLI arguments for manageExtension install")
  func cliArgumentsInstallExtension() async {
    let cli = VSCodeCLI(configuration: AuraConfiguration.mock.vscode, shell: testShell)
    let command: VSCodeCommand = .manageExtension(
      extensionID: "ms-python.python",
      action: .install
    )
    let args = await cli.makeArguments(for: command)
    #expect(args.contains("--install-extension"))
    #expect(args.contains("ms-python.python"))
  }

  // MARK: - Bridge

  @Test("static bridge returns injected editor state")
  func staticBridgeEditorState() async {
    let editor = VSCodeEditorState(
      activeFilePath: "/tmp/main.swift",
      languageID: "swift",
      isDirty: true,
      workspaceFolderPaths: ["/tmp"]
    )
    let bridge = VSCodeStaticBridge(editor: editor, terminal: nil, diagnostics: [])
    let state = await bridge.editorState(maxStalenessSeconds: 60)
    #expect(state?.activeFilePath == "/tmp/main.swift")
    #expect(state?.isDirty == true)
    #expect(bridge.isAvailable == true)
  }

  @Test("file bridge reports unavailable when state path is nil")
  func fileBridgeUnavailableWhenPathNil() async {
    let bridge = VSCodeFileBridge(statePath: nil)
    let state = await bridge.editorState(maxStalenessSeconds: 60)
    #expect(bridge.isAvailable == false)
    #expect(state == nil)
  }

  @Test("file bridge reads snapshot JSON")
  func fileBridgeReadsSnapshot() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let stateFile = tempDir.appendingPathComponent("vscode-state.json")
    let snapshot = VSCodeBridgeSnapshot(
      editor: VSCodeEditorState(
        activeFilePath: "/tmp/main.swift",
        isDirty: false,
        workspaceFolderPaths: ["/tmp"]
      ),
      terminal: VSCodeTerminalState(
        terminalID: "t1",
        shell: "/bin/zsh",
        workingDirectory: "/tmp"
      ),
      diagnostics: [],
      timestamp: Date()
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)
    try data.write(to: stateFile)

    let bridge = VSCodeFileBridge(statePath: stateFile.path, requireAuthentication: false)
    let editor = await bridge.editorState(maxStalenessSeconds: 60)
    let terminal = await bridge.terminalState(maxStalenessSeconds: 60)
    #expect(bridge.isAvailable == true)
    #expect(editor?.activeFilePath == "/tmp/main.swift")
    #expect(terminal?.shell == "/bin/zsh")

    try? FileManager.default.removeItem(at: tempDir)
  }

  @Test("authenticated bridge accepts a signed fresh snapshot")
  func authenticatedBridgeAcceptsSignedSnapshot() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let stateFile = tempDir.appendingPathComponent("vscode-authenticated-state.json")
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: "test-only-secret")
    let envelope = try authenticator.makeEnvelope(
      snapshot: VSCodeBridgeSnapshot(
        editor: VSCodeEditorState(
          activeFilePath: "/tmp/authenticated.swift",
          isDirty: false,
          workspaceFolderPaths: ["/tmp"])),
      extensionID: "ai.aura.vscode-bridge",
      nonce: UUID().uuidString)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(envelope).write(to: stateFile)

    let bridge = VSCodeFileBridge(
      statePath: stateFile.path,
      authenticator: authenticator,
      expectedExtensionID: "ai.aura.vscode-bridge")
    let editor = await bridge.editorState(maxStalenessSeconds: 60)
    #expect(bridge.isAvailable == true)
    #expect(editor?.activeFilePath == "/tmp/authenticated.swift")
  }

  @Test("authenticated bridge rejects tampering and nonce replay")
  func authenticatedBridgeRejectsTamperingAndReplay() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let stateFile = tempDir.appendingPathComponent("vscode-authenticated-state.json")
    let authenticator = try VSCodeBridgeAuthenticator(sharedSecret: "test-only-secret")
    let snapshot = VSCodeBridgeSnapshot(
      editor: VSCodeEditorState(activeFilePath: "/tmp/replay.swift"))
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    let first = try authenticator.makeEnvelope(
      snapshot: snapshot,
      extensionID: "ai.aura.vscode-bridge",
      nonce: "nonce-1")
    try encoder.encode(first).write(to: stateFile)
    let bridge = VSCodeFileBridge(
      statePath: stateFile.path,
      authenticator: authenticator,
      expectedExtensionID: "ai.aura.vscode-bridge")
    #expect((await bridge.editorState(maxStalenessSeconds: 60))?.activeFilePath == "/tmp/replay.swift")

    var tampered = first
    tampered = VSCodeBridgeEnvelope(payload: first.payload, authenticationTag: "tampered")
    try encoder.encode(tampered).write(to: stateFile)
    #expect(await bridge.editorState(maxStalenessSeconds: 60) == nil)

    let second = try authenticator.makeEnvelope(
      snapshot: snapshot,
      extensionID: "ai.aura.vscode-bridge",
      nonce: "nonce-2")
    try encoder.encode(second).write(to: stateFile)
    #expect((await bridge.editorState(maxStalenessSeconds: 60))?.activeFilePath == "/tmp/replay.swift")

    try encoder.encode(first).write(to: stateFile)
    #expect(await bridge.editorState(maxStalenessSeconds: 60) == nil)
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
}

extension AuraConfiguration {
  fileprivate static var mock: AuraConfiguration {
    AuraConfiguration()
  }
}
