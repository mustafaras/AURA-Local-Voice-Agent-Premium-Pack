import AuraAgent
import AuraCore
import Foundation
import Testing

private let codexArgumentsWorkingDirectory =
  ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"

@Test
func codexArgumentsAlwaysIncludeJSONAndNeverAsk() throws {
  let request = CodexRunRequest(
    prompt: "irrelevant here",
    workingDirectory: codexArgumentsWorkingDirectory,
    sandbox: .readOnly
  )
  let args = try CodexArguments.make(request: request, configuration: CodexConfiguration())
  #expect(args.contains("--json"))
  #expect(args.contains("-a"))
  let askIndex = args.firstIndex(of: "-a")!
  #expect(args[args.index(after: askIndex)] == "never")
}

@Test
func codexArgumentsNeverContainDangerousBypassFlag() throws {
  let request = CodexRunRequest(
    prompt: "irrelevant here",
    workingDirectory: codexArgumentsWorkingDirectory,
    sandbox: .workspaceWrite
  )
  let args = try CodexArguments.make(request: request, configuration: CodexConfiguration())
  #expect(!args.contains("--dangerously-bypass-approvals-and-sandbox"))
  #expect(!args.contains("--dangerously-bypass-hook-trust"))
}

@Test
func codexArgumentsNeverContainThePrompt() throws {
  let prompt = "list files; then summarize && report | done UNIQUE_MARKER_42"
  let request = CodexRunRequest(
    prompt: prompt, workingDirectory: codexArgumentsWorkingDirectory, sandbox: .readOnly)
  let args = try CodexArguments.make(request: request, configuration: CodexConfiguration())
  #expect(!args.contains(prompt))
  #expect(!args.contains { $0.contains("UNIQUE_MARKER_42") })
}

@Test
func codexArgumentsMapSandboxTiers() throws {
  let readOnly = CodexRunRequest(
    prompt: "p", workingDirectory: codexArgumentsWorkingDirectory, sandbox: .readOnly)
  let writable = CodexRunRequest(
    prompt: "p", workingDirectory: codexArgumentsWorkingDirectory, sandbox: .workspaceWrite)
  let readOnlyArgs = try CodexArguments.make(
    request: readOnly, configuration: CodexConfiguration())
  let writableArgs = try CodexArguments.make(
    request: writable, configuration: CodexConfiguration())
  #expect(readOnlyArgs.contains("read-only"))
  #expect(writableArgs.contains("workspace-write"))
  #expect(!readOnlyArgs.contains("danger-full-access"))
  #expect(!writableArgs.contains("danger-full-access"))
}

@Test
func codexArgumentsRejectWorkingDirectoryOutsideAllowlist() {
  let request = CodexRunRequest(prompt: "p", workingDirectory: "/etc", sandbox: .readOnly)
  #expect(throws: AuraError.self) {
    try CodexArguments.make(request: request, configuration: CodexConfiguration())
  }
}

@Test
func codexArgumentsRejectAddDirOutsideAllowlist() {
  let request = CodexRunRequest(
    prompt: "p",
    workingDirectory: codexArgumentsWorkingDirectory,
    sandbox: .workspaceWrite,
    additionalWritableDirectories: ["/etc"]
  )
  #expect(throws: AuraError.self) {
    try CodexArguments.make(request: request, configuration: CodexConfiguration())
  }
}

@Test
func codexArgumentsIncludeAllowedAddDir() throws {
  let subdirectory =
    (codexArgumentsWorkingDirectory as NSString).appendingPathComponent("scratch")
  let request = CodexRunRequest(
    prompt: "p",
    workingDirectory: codexArgumentsWorkingDirectory,
    sandbox: .workspaceWrite,
    additionalWritableDirectories: [subdirectory]
  )
  let args = try CodexArguments.make(request: request, configuration: CodexConfiguration())
  #expect(args.contains("--add-dir"))
  #expect(args.contains(subdirectory))
}

@Test
func codexArgumentsIncludeModelWhenSet() throws {
  let request = CodexRunRequest(
    prompt: "p", workingDirectory: codexArgumentsWorkingDirectory, sandbox: .readOnly, model: "o3"
  )
  let args = try CodexArguments.make(request: request, configuration: CodexConfiguration())
  #expect(args.contains("-m"))
  #expect(args.contains("o3"))
}

@Test
func codexArgumentsOmitConfigFlagsWhenDisabled() throws {
  var configuration = CodexConfiguration()
  configuration.ephemeralByDefault = false
  configuration.ignoreUserConfigByDefault = false
  configuration.skipGitRepoCheckByDefault = false
  let request = CodexRunRequest(
    prompt: "p", workingDirectory: codexArgumentsWorkingDirectory, sandbox: .readOnly)
  let args = try CodexArguments.make(request: request, configuration: configuration)
  #expect(!args.contains("--ephemeral"))
  #expect(!args.contains("--ignore-user-config"))
  #expect(!args.contains("--skip-git-repo-check"))
}
