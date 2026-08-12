import AuraContext
import AuraCore
import AuraMemory
import Foundation

/// Seam for step 3 ("generate typed intent candidate") of `docs/subsystems/
/// 08_INTENT_ENGINE.md`'s pipeline. `RuleBasedUtteranceClassifier` is the
/// only production conformer for this phase; a future NLU/LLM-backed
/// classifier can conform without changing `IntentEngine`, `ToolRouter`, or
/// the `TypedIntent` schema at all — only ever the *speed and accuracy* of
/// filling that schema changes, never what the schema allows.
public protocol UtteranceClassifying: Sendable {
  func classify(normalized: String, raw: String) -> ClassificationResult
}
