import AuraCore
import Foundation

/// Closed vocabulary of intents this v1 slice can dispatch. Never extended
/// implicitly — a classifier that doesn't recognize an utterance must
/// produce `.unknown`, never a made-up new kind, matching `docs/subsystems/
/// 08_INTENT_ENGINE.md`'s "may select among registered tools, never invent
/// one" rule.
public enum IntentKind: String, Codable, Sendable, Equatable, CaseIterable {
  case converse
  case appActivate
  case appTerminate
  case shellExecute
  case codingAgentRun
  case fileOpen
  case fileReveal
  case urlOpen
  // SP-010: the four read-first productivity capabilities. Each is reachable
  // only while its capability is `.ready` in the registry, which in turn
  // requires an onboarded account or profile — so an utterance naming a
  // disconnected integration is refused with a truthful reason instead of
  // reaching an adapter.
  case browserRead
  case mailRead
  case calendarRead
  case contactsLookup
  case unknown
}

/// One named, typed value extracted from an utterance — never a raw
/// substring passed straight into an executable action. `TypedIntent.slots`
/// is the only way structured data crosses from classification into
/// dispatch, mirroring `ComputerUseActionStep`'s "closed schema, never raw
/// string eval" precedent (`Sources/AuraComputerUse/
/// ComputerUseControlLoop.swift`).
public struct IntentSlot: Codable, Sendable, Equatable {
  public let name: String
  public let value: String

  public init(name: String, value: String) {
    self.name = name
    self.value = value
  }
}

/// Well-known slot names produced by `RuleBasedUtteranceClassifier` and
/// consumed by `ToolRouter`.
public enum IntentSlotName {
  public static let bundleIdentifier = "bundleIdentifier"
  public static let executable = "executable"
  public static let arguments = "arguments"  // space-joined; ToolRouter re-splits
  public static let backend = "backend"
  public static let objective = "objective"
  public static let unresolvedAppName = "unresolvedAppName"
  public static let filePath = "filePath"
  public static let folderPath = "folderPath"
  public static let url = "url"
  // SP-010 productivity slots. `accountID` and `profileID` are private
  // values: they may reach an adapter, but every event, log line, and prompt
  // quotes `ProductivityRedaction.fingerprint` instead.
  public static let accountID = "accountID"
  public static let profileID = "profileID"
  public static let query = "query"
  /// `true` only for an explicit thread-summary utterance. The same
  /// read-only `mail.read` capability owns both search and thread reads; this
  /// slot selects which typed adapter method runs without inventing a second
  /// capability or broadening OAuth scope.
  public static let threadSummary = "threadSummary"
  public static let dayRange = "dayRange"
}

/// The typed, closed-schema result of classifying one `TurnCompletedEvent`.
/// `riskTier`/`requiresMandatoryConfirmation` are always derived from
/// `semanticCategory` at construction time — never independently supplied —
/// so they can never drift out of sync with the category they describe.
public struct TypedIntent: Sendable, Equatable, Identifiable {
  public let id: UUID
  public let turnCorrelationID: UUID
  public let kind: IntentKind
  public let semanticCategory: IntentSemanticCategory
  public let rawUtterance: String
  public let normalizedUtterance: String
  public let slots: [IntentSlot]
  public let classificationConfidence: Double
  public let isAmbiguous: Bool
  public let language: DialogueLanguage
  public let dialogueAct: DialogueAct
  public let ambiguityReasons: [String]
  public let contextRequirements: [String]
  public let riskTier: PermissionRiskTier
  public let requiresMandatoryConfirmation: Bool
  public let turnContext: TurnContext?

  public init(
    id: UUID = UUID(),
    turnCorrelationID: UUID,
    kind: IntentKind,
    semanticCategory: IntentSemanticCategory,
    rawUtterance: String,
    normalizedUtterance: String,
    slots: [IntentSlot] = [],
    classificationConfidence: Double,
    isAmbiguous: Bool,
    language: DialogueLanguage = .unknown,
    dialogueAct: DialogueAct = .answer,
    ambiguityReasons: [String] = [],
    contextRequirements: [String] = [],
    turnContext: TurnContext? = nil
  ) {
    self.id = id
    self.turnCorrelationID = turnCorrelationID
    self.kind = kind
    self.semanticCategory = semanticCategory
    self.rawUtterance = rawUtterance
    self.normalizedUtterance = normalizedUtterance
    self.slots = slots
    self.classificationConfidence = min(max(classificationConfidence, 0), 1)
    self.isAmbiguous = isAmbiguous
    self.language = language
    self.dialogueAct = dialogueAct
    self.ambiguityReasons = ambiguityReasons
    self.contextRequirements = contextRequirements
    self.riskTier = semanticCategory.riskTier
    self.requiresMandatoryConfirmation = semanticCategory.requiresMandatoryConfirmation
    self.turnContext = turnContext
  }

  public func withTurnContext(_ context: TurnContext) -> TypedIntent {
    TypedIntent(
      id: id,
      turnCorrelationID: turnCorrelationID,
      kind: kind,
      semanticCategory: semanticCategory,
      rawUtterance: rawUtterance,
      normalizedUtterance: normalizedUtterance,
      slots: slots,
      classificationConfidence: classificationConfidence,
      isAmbiguous: isAmbiguous,
      language: language,
      dialogueAct: dialogueAct,
      ambiguityReasons: ambiguityReasons,
      contextRequirements: contextRequirements,
      turnContext: context)
  }

  public func slotValue(_ name: String) -> String? {
    slots.first { $0.name == name }?.value
  }

  /// A copy with `semanticCategory` changed — used by `ToolRouter` to
  /// escalate `.shellExecute` to `.shellDestructive` after a destructive
  /// pattern match. Keeps `id`/slots/confidence intact; only the category
  /// (and its derived `riskTier`/`requiresMandatoryConfirmation`) changes.
  public func escalated(to newCategory: IntentSemanticCategory) -> TypedIntent {
    TypedIntent(
      id: id, turnCorrelationID: turnCorrelationID, kind: kind, semanticCategory: newCategory,
      rawUtterance: rawUtterance, normalizedUtterance: normalizedUtterance, slots: slots,
      classificationConfidence: classificationConfidence, isAmbiguous: isAmbiguous,
      language: language, dialogueAct: dialogueAct, ambiguityReasons: ambiguityReasons,
      contextRequirements: contextRequirements,
      turnContext: turnContext)
  }
}
