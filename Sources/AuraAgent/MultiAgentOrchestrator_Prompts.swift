import AuraCore
import AuraPolicy
import AuraSecurity
import AuraShell
import Foundation

extension MultiAgentOrchestrator {
  // MARK: - Prompts

  /// `objective` and `acceptanceCriteria` originate from the live user and
  /// carry authority, so they are not screened — a user cannot inject into
  /// their own request. Everything else interpolated below does *not*: a diff
  /// is repository content, validation output is terminal output, and reviewer
  /// feedback and the plan are another model's output. Each of those is a
  /// documented injection surface, so each is screened before it can reach a
  /// model as text (`RISK-INJECTION-COVERAGE-NON-DIALOGUE`).
  static let injectionScreen = PromptInjectionScreen()

  static func plannerPrompt(objective: String, acceptanceCriteria: [String]) -> String {
    """
    You are the PLANNER in a bounded multi-agent workflow. You are read-only \
    — do not write or modify any files. Produce a concise, concrete \
    implementation plan for the following objective.

    Objective: \(objective)

    Acceptance criteria:
    \(bulletList(acceptanceCriteria))

    Respond with the plan only.
    """
  }

  static func implementerPrompt(
    objective: String, plan: String, acceptanceCriteria: [String]
  ) -> String {
    """
    You are the IMPLEMENTER in a bounded multi-agent workflow. Make the \
    necessary changes directly in the current working directory to satisfy \
    the objective below, following the plan.

    Objective: \(objective)

    Plan:
    \(injectionScreen.screen(plan, provenance: .agentToolOutput))

    Acceptance criteria:
    \(bulletList(acceptanceCriteria))
    """
  }

  static func reviewerPrompt(
    objective: String, acceptanceCriteria: [String], diff: String, validation: ValidationOutcome?
  ) -> String {
    let validationSection: String
    if let validation {
      validationSection = """
        Validation command result: \(validation.passed ? "PASSED" : "FAILED") "
          + "(exit code \(validation.exitCode))"
        \(injectionScreen.screen(validation.outputTail, provenance: .terminalOutput))
        """
    } else {
      validationSection = "No validation command was run."
    }

    return """
      You are the REVIEWER in a bounded multi-agent workflow. You are \
      read-only — do not modify any files. Adjudicate based on tests, \
      security, specification compliance, simplicity, and maintainability. \
      Do not rely on any summary from the implementer — base your verdict \
      only on the diff and validation result shown below.

      Objective: \(objective)

      Acceptance criteria:
      \(bulletList(acceptanceCriteria))

      Diff:
      \(injectionScreen.screen(diff, provenance: .repositoryFile))

      \(validationSection)

      End your response with exactly one line, and nothing after it:
      "VERDICT: APPROVE" if the change satisfies the objective and acceptance \
      criteria, or "VERDICT: REQUEST_CHANGES: <reason>" otherwise.
      """
  }

  static func correctorPrompt(
    objective: String, feedback: String?, validation: ValidationOutcome?
  ) -> String {
    let validationSection =
      validation.map {
        "Validation command output:\n"
          + injectionScreen.screen($0.outputTail, provenance: .terminalOutput)
      } ?? ""
    let screenedFeedback = feedback.map {
      injectionScreen.screen($0, provenance: .agentToolOutput)
    }
    return """
      You are the IMPLEMENTER addressing reviewer feedback in a bounded \
      multi-agent workflow. Make the necessary changes directly in the \
      current working directory.

      Objective: \(objective)

      Reviewer feedback: \(screenedFeedback ?? "no reason given")

      \(validationSection)
      """
  }

  /// Embeds the worktree path/branch in a failure reason so a caller can
  /// still find and inspect (or clean up) work already done by the time a
  /// later role fails — a `.failed` outcome loses this otherwise, since only
  /// `.approved`/`.escalated` carry `worktreePath`/`branch`.
  static func failureReason(_ reason: String, handle: WorktreeHandle) -> String {
    "\(reason) (worktree: \(handle.path), branch: \(handle.branch))"
  }

  static func bulletList(_ items: [String]) -> String {
    items.isEmpty ? "(none specified)" : items.map { "- \($0)" }.joined(separator: "\n")
  }

  static func reasonText(for verdict: ReviewVerdict) -> String? {
    switch verdict {
    case .approve:
      return nil
    case .requestChanges(let reason):
      return reason
    case .unparseable:
      return "reviewer response did not contain a recognizable VERDICT marker"
    }
  }
}
