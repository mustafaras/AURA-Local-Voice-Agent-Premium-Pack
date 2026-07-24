import AuraCore
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

    let bridge = VSCodeFileBridge(statePath: stateFile.path)
    let editor = await bridge.editorState(maxStalenessSeconds: 60)
    let terminal = await bridge.terminalState(maxStalenessSeconds: 60)
    #expect(bridge.isAvailable == true)
    #expect(editor?.activeFilePath == "/tmp/main.swift")
    #expect(terminal?.shell == "/bin/zsh")

    try? FileManager.default.removeItem(at: tempDir)
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
}

extension AuraConfiguration {
  fileprivate static var mock: AuraConfiguration {
    AuraConfiguration()
  }
}
