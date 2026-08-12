import AuraCore
import AuraPolicy
import AuraShell
import Foundation

extension MultiAgentOrchestrator {
  // MARK: - Validation command

  func runValidation(
    command: Command,
    workingDirectory: String,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID
  ) async -> ValidationOutcome? {
    guard let validationShell else { return nil }

    let policyRequest = PolicyEvaluationRequest(
      capability: .shellExec,
      actor: actor,
      target: PolicyTarget(
        directoryPath: workingDirectory, command: command.executable,
        arguments: command.arguments),
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: correlationID
    )
    let decision = await policyEngine.evaluate(policyRequest)
    guard case .allow = decision else {
      return ValidationOutcome(passed: false, exitCode: -1, outputTail: "denied by policy")
    }

    let scoped = Command(
      executable: command.executable,
      arguments: command.arguments,
      workingDirectory: workingDirectory,
      environment: command.environment,
      timeoutSeconds: command.timeoutSeconds,
      expectedExitCodes: command.expectedExitCodes,
      riskTier: command.riskTier,
      standardInputText: command.standardInputText,
      trailingArgument: command.trailingArgument
    )
    let result = await validationShell.execute(
      command: scoped, actor: actor, sessionID: sessionID, correlationID: correlationID,
      causationID: correlationID)

    switch result {
    case .success(let processResult):
      let combined = processResult.stdout + "\n" + processResult.stderr
      return ValidationOutcome(
        passed: processResult.exitCode == 0,
        exitCode: processResult.exitCode,
        outputTail: String(combined.suffix(2000)))
    case .failure(let error):
      return ValidationOutcome(passed: false, exitCode: -1, outputTail: error.localizedDescription)
    }
  }
}
