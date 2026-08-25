import AuraCore
import Foundation

extension RuleBasedUtteranceClassifier {
  /// Classify an open-prefixed target that names a previously mentioned entity
  /// rather than a literal path.
  ///
  /// Returns `nil` when the target is not a known reference phrase, so ordinary
  /// application names ("open safari") still fall through to
  /// `classifyAppCommand` unchanged.
  func implicitReferenceIntent(in target: String) -> ClassificationResult? {
    guard let reference = ImplicitReferencePhrases.firstMatch(in: target) else { return nil }
    // "the app" must resolve against recent applications, not recent files:
    // `TypedIntent.applyingResolvedReference` only binds a candidate whose kind
    // matches the intent, so the wrong pairing would silently never bind.
    let isApplication = ImplicitReferencePhrases.applicationPhrases.contains(reference)
    // Above `minimumClassificationConfidence` (0.6) so the intent survives the
    // confidence gate, but below an explicit path's 0.85: the action is known,
    // the target is not.
    return ClassificationResult(
      kind: isApplication ? .appActivate : .fileOpen,
      semanticCategory: isApplication ? .appActivate : .fileOpen,
      slots: [],
      confidence: 0.7,
      dialogueAct: .execute,
      contextRequirements: [isApplication ? "bundleIdentifier" : "filePath"])
  }
}
