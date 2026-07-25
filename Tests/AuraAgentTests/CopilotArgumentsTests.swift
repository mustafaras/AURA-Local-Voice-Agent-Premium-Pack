import AuraAgent
import AuraCore
import Foundation
import Testing

private let copilotAllowedWorkingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"

@Test
func copilotArgumentsAlwaysEndWithDashP() throws {
  let request = CopilotRunRequest(
    objective: "irrelevant here",
    workingDirectory: copilotAllowedWorkingDirectory,
    toolProfile: .readOnly
  )
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(args.last == "-p")
}

@Test
func copilotArgumentsNeverContainDangerousBypassFlags() throws {
  let request = CopilotRunRequest(
    objective: "irrelevant here",
    workingDirectory: copilotAllowedWorkingDirectory,
    toolProfile: .workspaceWrite
  )
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(!args.contains("--allow-all"))
  #expect(!args.contains("--yolo"))
  #expect(!args.contains("--allow-all-paths"))
  #expect(!args.contains("--allow-all-urls"))
  #expect(!args.contains("--remote"))
  #expect(!args.contains("--remote-export"))
  #expect(!args.contains("--share"))
  #expect(!args.contains("--share-gist"))
  #expect(!args.contains("--connect"))
}

@Test
func copilotArgumentsNeverContainTheObjective() throws {
  // The objective is delivered via Command.trailingArgument, not here —
  // verify none of the built argv elements ever equal or embed it.
  let objective = "list files; then summarize && report | done UNIQUE_MARKER_55"
  let request = CopilotRunRequest(
    objective: objective, workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(!args.contains(objective))
  #expect(!args.contains { $0.contains("UNIQUE_MARKER_55") })
}

@Test
func copilotArgumentsMapToolProfiles() throws {
  let readOnly = CopilotRunRequest(
    objective: "p", workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .readOnly)
  let writable = CopilotRunRequest(
    objective: "p", workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .workspaceWrite)
  let readOnlyArgs = try CopilotArguments.make(
    request: readOnly, configuration: CopilotConfiguration())
  let writableArgs = try CopilotArguments.make(
    request: writable, configuration: CopilotConfiguration())
  #expect(readOnlyArgs.contains("--available-tools="))
  #expect(!readOnlyArgs.contains("--allow-all-tools"))
  #expect(writableArgs.contains("--allow-all-tools"))
  #expect(!writableArgs.contains { $0.hasPrefix("--available-tools=") })
}

@Test
func copilotArgumentsAlwaysDisableBuiltinMCPs() throws {
  let request = CopilotRunRequest(
    objective: "p", workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(args.contains("--disable-builtin-mcps"))
}

@Test
func copilotArgumentsOmitNoCustomInstructionsByDefault() throws {
  let request = CopilotRunRequest(
    objective: "p", workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(!args.contains("--no-custom-instructions"))
}

@Test
func copilotArgumentsIncludeNoCustomInstructionsWhenDisabled() throws {
  var configuration = CopilotConfiguration()
  configuration.loadCustomInstructionsByDefault = false
  let request = CopilotRunRequest(
    objective: "p", workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try CopilotArguments.make(request: request, configuration: configuration)
  #expect(args.contains("--no-custom-instructions"))
}

@Test
func copilotArgumentsRejectWorkingDirectoryOutsideAllowlist() {
  let request = CopilotRunRequest(objective: "p", workingDirectory: "/etc", toolProfile: .readOnly)
  #expect(throws: AuraError.self) {
    try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  }
}

@Test
func copilotArgumentsRejectAddDirOutsideAllowlist() {
  let request = CopilotRunRequest(
    objective: "p",
    workingDirectory: copilotAllowedWorkingDirectory,
    toolProfile: .workspaceWrite,
    additionalWritableDirectories: ["/etc"]
  )
  #expect(throws: AuraError.self) {
    try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  }
}

@Test
func copilotArgumentsIncludeAllowedAddDir() throws {
  let subdirectory = (copilotAllowedWorkingDirectory as NSString).appendingPathComponent("scratch")
  let request = CopilotRunRequest(
    objective: "p",
    workingDirectory: copilotAllowedWorkingDirectory,
    toolProfile: .workspaceWrite,
    additionalWritableDirectories: [subdirectory]
  )
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(args.contains("--add-dir"))
  #expect(args.contains(subdirectory))
}

@Test
func copilotArgumentsIncludeModelWhenSet() throws {
  let request = CopilotRunRequest(
    objective: "p", workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .readOnly,
    model: "gpt-5-mini"
  )
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(args.contains("--model"))
  #expect(args.contains("gpt-5-mini"))
}

@Test
func copilotArgumentsIncludeMaxAICreditsWhenSet() throws {
  let request = CopilotRunRequest(
    objective: "p", workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .readOnly,
    maxAICredits: 100
  )
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(args.contains("--max-ai-credits"))
  #expect(args.contains("100"))
}

@Test
func copilotArgumentsOmitMaxAICreditsWhenNotSet() throws {
  let request = CopilotRunRequest(
    objective: "p", workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(!args.contains("--max-ai-credits"))
}

@Test
func copilotArgumentsIncludeJSONOutputAndSilent() throws {
  let request = CopilotRunRequest(
    objective: "p", workingDirectory: copilotAllowedWorkingDirectory, toolProfile: .readOnly)
  let args = try CopilotArguments.make(request: request, configuration: CopilotConfiguration())
  #expect(args.contains("--output-format"))
  #expect(args.contains("json"))
  #expect(args.contains("--silent"))
}
