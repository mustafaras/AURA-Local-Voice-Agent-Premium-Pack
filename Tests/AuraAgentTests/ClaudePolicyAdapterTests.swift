import AuraAgent
import AuraCore
import Foundation
import Testing

@Test
func claudePolicyAdapterMapsReadOnlyToReadOnlyCapability() {
  let request = ClaudeRunRequest(objective: "p", workingDirectory: "/tmp", toolProfile: .readOnly)
  let policyRequest = ClaudePolicyAdapter.request(
    for: request, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.capability == .agentClaudeReadOnly)
  #expect(policyRequest.capability.riskTier == .reversible)
}

@Test
func claudePolicyAdapterMapsWorkspaceWriteToDestructiveCapability() {
  let request = ClaudeRunRequest(
    objective: "p", workingDirectory: "/tmp", toolProfile: .workspaceWrite)
  let policyRequest = ClaudePolicyAdapter.request(
    for: request, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.capability == .agentClaudeRun)
  #expect(policyRequest.capability.riskTier == .destructive)
}

@Test
func claudePolicyAdapterExcludesObjectiveFromTarget() {
  let secretObjective = "the secret objective text UNIQUE_MARKER_88"
  let request = ClaudeRunRequest(
    objective: secretObjective, workingDirectory: "/tmp", toolProfile: .readOnly)
  let policyRequest = ClaudePolicyAdapter.request(
    for: request, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.target.filePath != secretObjective)
  #expect(policyRequest.target.command != secretObjective)
  #expect(!policyRequest.target.arguments.contains(secretObjective))
}

@Test
func claudePolicyAdapterCarriesWorkingDirectoryAsTarget() {
  let request = ClaudeRunRequest(
    objective: "p",
    workingDirectory: "/tmp/project",
    toolProfile: .workspaceWrite,
    additionalWritableDirectories: ["/tmp/scratch"]
  )
  let policyRequest = ClaudePolicyAdapter.request(
    for: request, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.target.directoryPath == "/tmp/project")
  #expect(policyRequest.target.arguments == ["/tmp/scratch"])
}
