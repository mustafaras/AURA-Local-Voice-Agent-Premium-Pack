import AuraCore
import AuraPolicy
import AuraShell
import Foundation

extension MultiAgentOrchestrator {
  // MARK: - Prompts

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
    \(plan)

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
        \(validation.outputTail)
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
      \(diff)

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
      validation.map { "Validation command output:\n\($0.outputTail)" } ?? ""
    return """
      You are the IMPLEMENTER addressing reviewer feedback in a bounded \
      multi-agent workflow. Make the necessary changes directly in the \
      current working directory.

      Objective: \(objective)

      Reviewer feedback: \(feedback ?? "no reason given")

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
