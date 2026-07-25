import AuraAgent
import AuraCore
import Foundation
import Testing

@Test
func copilotPolicyAdapterMapsReadOnlyToReadOnlyCapability() {
  let request = CopilotRunRequest(objective: "p", workingDirectory: "/tmp", toolProfile: .readOnly)
  let policyRequest = CopilotPolicyAdapter.request(
    for: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.capability == .agentCopilotReadOnly)
  #expect(policyRequest.capability.riskTier == .reversible)
}

@Test
func copilotPolicyAdapterMapsWorkspaceWriteToDestructiveCapability() {
  let request = CopilotRunRequest(
    objective: "p", workingDirectory: "/tmp", toolProfile: .workspaceWrite)
  let policyRequest = CopilotPolicyAdapter.request(
    for: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.capability == .agentCopilotRun)
  #expect(policyRequest.capability.riskTier == .destructive)
}

@Test
func copilotPolicyAdapterExcludesObjectiveFromTarget() {
  let secretObjective = "the secret objective text UNIQUE_MARKER_66"
  let request = CopilotRunRequest(
    objective: secretObjective, workingDirectory: "/tmp", toolProfile: .readOnly)
  let policyRequest = CopilotPolicyAdapter.request(
    for: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.target.filePath != secretObjective)
  #expect(policyRequest.target.command != secretObjective)
  #expect(!policyRequest.target.arguments.contains(secretObjective))
}

@Test
func copilotPolicyAdapterCarriesWorkingDirectoryAsTarget() {
  let request = CopilotRunRequest(
    objective: "p",
    workingDirectory: "/tmp/project",
    toolProfile: .workspaceWrite,
    additionalWritableDirectories: ["/tmp/scratch"]
  )
  let policyRequest = CopilotPolicyAdapter.request(
    for: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.target.directoryPath == "/tmp/project")
  #expect(policyRequest.target.arguments == ["/tmp/scratch"])
}
