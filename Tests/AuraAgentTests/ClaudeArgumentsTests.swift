import AuraAgent
import AuraCore
import Foundation
import Testing

private let claudeAllowedWorkingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"

@Test
func claudeArgumentsAlwaysIncludePrintAndDontAsk() throws {
  let request = ClaudeRunRequest(
    objective: "irrelevant here",
    workingDirectory: claudeAllowedWorkingDirectory,
    toolProfile: .readOnly
  )
  let args = try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  #expect(args.contains("-p"))
  #expect(args.contains("--permission-mode"))
  let modeIndex = args.firstIndex(of: "--permission-mode")!
  #expect(args[args.index(after: modeIndex)] == "dontAsk")
}

@Test
func claudeArgumentsMapWriteCapableToAcceptEdits() throws {
  // A write-capable turn must use `acceptEdits` (auto-approve edits confined
  // to the isolated worktree) so it can actually produce a diff; it must never
  // use the deny-only `dontAsk` (which makes real writes impossible) nor a
  // bypass flag. The mode is derived from the tool profile.
  let readOnly = ClaudeRunRequest(
    objective: "p", workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .readOnly)
  let writable = ClaudeRunRequest(
    objective: "p", workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .workspaceWrite)
  let args = try ClaudeArguments.make(request: writable, configuration: ClaudeConfiguration())
  let modeIndex = args.firstIndex(of: "--permission-mode")!
  #expect(args[args.index(after: modeIndex)] == "acceptEdits")
  #expect(claudePermissionMode(for: readOnly.toolProfile) == "dontAsk")
  #expect(claudePermissionMode(for: writable.toolProfile) == "acceptEdits")
  #expect(!args.contains("--dangerously-skip-permissions"))
  #expect(!args.contains("--allow-dangerously-skip-permissions"))
  #expect(!args.contains("bypassPermissions"))
}

@Test
func claudeArgumentsNeverContainDangerousBypassFlags() throws {
  let request = ClaudeRunRequest(
    objective: "irrelevant here",
    workingDirectory: claudeAllowedWorkingDirectory,
    toolProfile: .workspaceWrite
  )
  let args = try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  #expect(!args.contains("--dangerously-skip-permissions"))
  #expect(!args.contains("--allow-dangerously-skip-permissions"))
}

@Test
func claudeArgumentsNeverContainTheObjective() throws {
  let objective = "list files; then summarize && report | done UNIQUE_MARKER_77"
  let request = ClaudeRunRequest(
    objective: objective, workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  #expect(!args.contains(objective))
  #expect(!args.contains { $0.contains("UNIQUE_MARKER_77") })
  #expect(args.last == claudeWrapperPrompt)
}

@Test
func claudeArgumentsMapToolProfiles() throws {
  let readOnly = ClaudeRunRequest(
    objective: "p", workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .readOnly)
  let writable = ClaudeRunRequest(
    objective: "p", workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .workspaceWrite)
  let configuration = ClaudeConfiguration()
  let readOnlyArgs = try ClaudeArguments.make(request: readOnly, configuration: configuration)
  let writableArgs = try ClaudeArguments.make(request: writable, configuration: configuration)

  let readOnlyToolsIndex = readOnlyArgs.firstIndex(of: "--tools")!
  #expect(
    readOnlyArgs[readOnlyArgs.index(after: readOnlyToolsIndex)]
      == configuration.readOnlyTools.joined(separator: ","))
  let writableToolsIndex = writableArgs.firstIndex(of: "--tools")!
  #expect(
    writableArgs[writableArgs.index(after: writableToolsIndex)]
      == configuration.workspaceWriteTools.joined(separator: ","))
  #expect(configuration.workspaceWriteTools.contains("Bash"))
  #expect(!configuration.readOnlyTools.contains("Bash"))
  #expect(!configuration.readOnlyTools.contains("Write"))
  #expect(!configuration.readOnlyTools.contains("Edit"))
}

@Test
func claudeArgumentsRejectWorkingDirectoryOutsideAllowlist() {
  let request = ClaudeRunRequest(objective: "p", workingDirectory: "/etc", toolProfile: .readOnly)
  #expect(throws: AuraError.self) {
    try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  }
}

@Test
func claudeArgumentsRejectAddDirOutsideAllowlist() {
  let request = ClaudeRunRequest(
    objective: "p",
    workingDirectory: claudeAllowedWorkingDirectory,
    toolProfile: .workspaceWrite,
    additionalWritableDirectories: ["/etc"]
  )
  #expect(throws: AuraError.self) {
    try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  }
}

@Test
func claudeArgumentsIncludeAllowedAddDir() throws {
  let subdirectory = (claudeAllowedWorkingDirectory as NSString).appendingPathComponent("scratch")
  let request = ClaudeRunRequest(
    objective: "p",
    workingDirectory: claudeAllowedWorkingDirectory,
    toolProfile: .workspaceWrite,
    additionalWritableDirectories: [subdirectory]
  )
  let args = try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  #expect(args.contains("--add-dir"))
  #expect(args.contains(subdirectory))
}

@Test
func claudeArgumentsIncludeModelWhenSet() throws {
  let request = ClaudeRunRequest(
    objective: "p", workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .readOnly,
    model: "sonnet"
  )
  let args = try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  #expect(args.contains("--model"))
  #expect(args.contains("sonnet"))
}

@Test
func claudeArgumentsIncludeMaxBudgetWhenSet() throws {
  let request = ClaudeRunRequest(
    objective: "p", workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .readOnly,
    maxCostUSD: 0.5
  )
  let args = try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  #expect(args.contains("--max-budget-usd"))
  #expect(args.contains("0.5"))
}

@Test
func claudeArgumentsOmitMaxBudgetWhenNotSet() throws {
  let request = ClaudeRunRequest(
    objective: "p", workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  #expect(!args.contains("--max-budget-usd"))
}

@Test
func claudeArgumentsExcludeProjectAndLocalSettingSourcesByDefault() throws {
  let request = ClaudeRunRequest(
    objective: "p", workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try ClaudeArguments.make(request: request, configuration: ClaudeConfiguration())
  let sourcesIndex = args.firstIndex(of: "--setting-sources")!
  let value = args[args.index(after: sourcesIndex)]
  #expect(value == "user")
  #expect(!value.contains("project"))
  #expect(!value.contains("local"))
}

@Test
func claudeArgumentsIncludeNoSessionPersistenceWhenEphemeral() throws {
  var configuration = ClaudeConfiguration()
  configuration.ephemeralByDefault = true
  let request = ClaudeRunRequest(
    objective: "p", workingDirectory: claudeAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try ClaudeArguments.make(request: request, configuration: configuration)
  #expect(args.contains("--no-session-persistence"))
}
