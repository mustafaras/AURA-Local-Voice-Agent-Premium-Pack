import AuraCore

/// Intent classification and tool routing: the previously-missing decision
/// layer between `Conversation` (turn-taking, `AuraAgent`) and the already-
/// real backend subsystems (`AuraPolicy`, `AuraAutomation`, `AuraShell`,
/// `AuraTasks`, the CLI agent adapters). Implements `docs/subsystems/
/// 08_INTENT_ENGINE.md`'s classification pipeline and `09_TOOL_ROUTER.md`'s
/// tool contract/dispatch model with a deliberately small, closed v1
/// vocabulary (`IntentKind`): converse, appActivate, appTerminate,
/// shellExecute, codingAgentRun. Expanding the vocabulary, swapping the
/// rule-based classifier for a real NLU/LLM classifier, and wiring
/// `ContextEngine.resolveReference` for pronoun slots are explicitly
/// deferred follow-ups, not attempted here.
public enum AuraIntent {
  public static let version = "1.0.0"
}
