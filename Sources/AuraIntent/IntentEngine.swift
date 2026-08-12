import AuraContext
import AuraCore
import AuraMemory
import Foundation

/// One classifier's raw output before `IntentEngine` applies the
/// confidence gate. Never carries a risk tier itself — that is always
/// derived from `semanticCategory` by `TypedIntent`'s initializer.
public struct ClassificationResult: Sendable, Equatable {
  public let kind: IntentKind
  public let semanticCategory: IntentSemanticCategory
  public let slots: [IntentSlot]
  public let confidence: Double
  public let proposedKind: IntentKind?
  public let language: DialogueLanguage
  public let dialogueAct: DialogueAct
  public let ambiguityReasons: [String]
  public let contextRequirements: [String]

  public init(
    kind: IntentKind,
    semanticCategory: IntentSemanticCategory,
    slots: [IntentSlot] = [],
    confidence: Double,
    proposedKind: IntentKind? = nil,
    language: DialogueLanguage = .unknown,
    dialogueAct: DialogueAct = .answer,
    ambiguityReasons: [String] = [],
    contextRequirements: [String] = []
  ) {
    self.kind = kind
    self.semanticCategory = semanticCategory
    self.slots = slots
    self.confidence = confidence
    self.proposedKind = proposedKind
    self.language = language
    self.dialogueAct = dialogueAct
    self.ambiguityReasons = ambiguityReasons
    self.contextRequirements = contextRequirements
  }

  public func withLanguage(_ language: DialogueLanguage) -> ClassificationResult {
    let act: DialogueAct
    switch kind {
    case .converse: act = .answer
    case .unknown: act = .clarify
    case .codingAgentRun: act = .delegate
    default: act = .execute
    }
    return ClassificationResult(
      kind: kind,
      semanticCategory: semanticCategory,
      slots: slots,
      confidence: confidence,
      proposedKind: proposedKind,
      language: language,
      dialogueAct: act,
      ambiguityReasons: ambiguityReasons,
      contextRequirements: contextRequirements)
  }

  public func applying(_ proposal: StructuredNLUProposal) -> ClassificationResult {
    let language = proposal.language == .unknown ? self.language : proposal.language
    let reason = proposal.ambiguityReason ?? "model proposal requires typed capability validation"
    guard proposal.dialogueAct == .answer, proposal.capabilityID == nil else {
      return ClassificationResult(
        kind: .unknown,
        semanticCategory: .unknown,
        slots: [],
        confidence: min(confidence, proposal.confidence),
        language: language,
        dialogueAct: .clarify,
        ambiguityReasons: [reason],
        contextRequirements: contextRequirements)
    }
    return ClassificationResult(
      kind: .converse,
      semanticCategory: .converse,
      slots: slots,
      confidence: proposal.confidence,
      proposedKind: nil,
      language: language,
      dialogueAct: .answer,
      ambiguityReasons: ambiguityReasons,
      contextRequirements: contextRequirements)
  }
}
