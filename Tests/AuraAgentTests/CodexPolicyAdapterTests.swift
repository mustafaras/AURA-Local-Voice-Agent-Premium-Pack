import AuraAgent
import AuraCore
import Foundation
import Testing

@Test
func codexPolicyAdapterMapsReadOnlyToReadOnlyCapability() {
  let request = CodexRunRequest(prompt: "p", workingDirectory: "/tmp", sandbox: .readOnly)
  let policyRequest = CodexPolicyAdapter.request(
    for: request, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.capability == .agentCodexReadOnly)
  #expect(policyRequest.capability.riskTier == .reversible)
}

@Test
func codexPolicyAdapterMapsWorkspaceWriteToDestructiveCapability() {
  let request = CodexRunRequest(prompt: "p", workingDirectory: "/tmp", sandbox: .workspaceWrite)
  let policyRequest = CodexPolicyAdapter.request(
    for: request, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.capability == .agentCodexRun)
  #expect(policyRequest.capability.riskTier == .destructive)
}

@Test
func codexPolicyAdapterExcludesPromptFromTarget() {
  let secretPrompt = "the secret prompt text UNIQUE_MARKER_99"
  let request = CodexRunRequest(
    prompt: secretPrompt, workingDirectory: "/tmp", sandbox: .readOnly)
  let policyRequest = CodexPolicyAdapter.request(
    for: request, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.target.filePath != secretPrompt)
  #expect(policyRequest.target.command != secretPrompt)
  #expect(!policyRequest.target.arguments.contains(secretPrompt))
}

@Test
func codexPolicyAdapterCarriesWorkingDirectoryAsTarget() {
  let request = CodexRunRequest(
    prompt: "p",
    workingDirectory: "/tmp/project",
    sandbox: .workspaceWrite,
    additionalWritableDirectories: ["/tmp/scratch"]
  )
  let policyRequest = CodexPolicyAdapter.request(
    for: request, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  #expect(policyRequest.target.directoryPath == "/tmp/project")
  #expect(policyRequest.target.arguments == ["/tmp/scratch"])
}
