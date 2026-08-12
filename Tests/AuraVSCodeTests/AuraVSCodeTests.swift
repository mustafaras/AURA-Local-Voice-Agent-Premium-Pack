import AuraCore
import AuraPolicy
import AuraShell
import AuraVSCode
import Foundation
import Testing

@Suite("AuraVSCode")
struct AuraVSCodeTests {
  let testActor: ActorID = .agentCodex

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

  var testShell: AuraShell { AuraShell(configuration: AuraConfiguration.mock.shell) }

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
    #expect(
      (await bridge.editorState(maxStalenessSeconds: 60))?.activeFilePath == "/tmp/replay.swift")

    var tampered = first
    tampered = VSCodeBridgeEnvelope(payload: first.payload, authenticationTag: "tampered")
    try encoder.encode(tampered).write(to: stateFile)
    #expect(await bridge.editorState(maxStalenessSeconds: 60) == nil)

    let second = try authenticator.makeEnvelope(
      snapshot: snapshot,
      extensionID: "ai.aura.vscode-bridge",
      nonce: "nonce-2")
    try encoder.encode(second).write(to: stateFile)
    #expect(
      (await bridge.editorState(maxStalenessSeconds: 60))?.activeFilePath == "/tmp/replay.swift")

    try encoder.encode(first).write(to: stateFile)
    #expect(await bridge.editorState(maxStalenessSeconds: 60) == nil)
  }

}

extension AuraConfiguration {
  static var mock: AuraConfiguration {
    AuraConfiguration()
  }
}
