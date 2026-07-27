import AuraCore
import AuraContext
import Foundation

/// One classifier's raw output before `IntentEngine` applies the
/// confidence gate. Never carries a risk tier itself — that is always
/// derived from `semanticCategory` by `TypedIntent`'s initializer.
public struct ClassificationResult: Sendable, Equatable {
  public let kind: IntentKind
  public let semanticCategory: IntentSemanticCategory
  public let slots: [IntentSlot]
  public let confidence: Double

  public init(
    kind: IntentKind, semanticCategory: IntentSemanticCategory, slots: [IntentSlot] = [],
    confidence: Double
  ) {
    self.kind = kind
    self.semanticCategory = semanticCategory
    self.slots = slots
    self.confidence = confidence
  }
}

/// Seam for step 3 ("generate typed intent candidate") of `docs/subsystems/
/// 08_INTENT_ENGINE.md`'s pipeline. `RuleBasedUtteranceClassifier` is the
/// only production conformer for this phase; a future NLU/LLM-backed
/// classifier can conform without changing `IntentEngine`, `ToolRouter`, or
/// the `TypedIntent` schema at all — only ever the *speed and accuracy* of
/// filling that schema changes, never what the schema allows.
public protocol UtteranceClassifying: Sendable {
  func classify(normalized: String, raw: String) -> ClassificationResult
}

/// Deterministic, keyword-driven classifier over the closed v1 vocabulary —
/// no model, no network dependency, fully reproducible in tests. Every
/// resolvable app name and shell executable is drawn from a small,
/// explicit, closed lookup table; an utterance that *looks* like a command
/// but names something outside that table is deliberately classified
/// `.unknown` rather than guessing a bundle identifier or executable path.
public struct RuleBasedUtteranceClassifier: UtteranceClassifying, Sendable {
  /// Closed app-name → bundle-identifier table for the v1 vocabulary.
  public static let knownApplications: [String: String] = [
    "safari": "com.apple.Safari",
    "mail": "com.apple.mail",
    "finder": "com.apple.finder",
    "terminal": "com.apple.Terminal",
    "calculator": "com.apple.calculator",
    "notes": "com.apple.Notes",
    "calendar": "com.apple.iCal",
    "music": "com.apple.Music",
  ]

  /// Closed executable-name → absolute-path table for the v1 vocabulary.
  /// An utterance naming an executable outside this table, and not itself
  /// an absolute path, is classified `.unknown` — never guessed.
  public static let knownExecutables: [String: String] = [
    "echo": "/bin/echo",
    "ls": "/bin/ls",
    "pwd": "/bin/pwd",
    "date": "/bin/date",
    "whoami": "/usr/bin/whoami",
  ]

  private static let agentTriggers: [String: String] = [
    "codex ": "codex",
    "claude ": "claude",
    "copilot ": "copilot",
  ]
  private static let genericAgentTriggers = [
    "ask the coding agent to ",
    "have the coding agent ",
  ]
  private static let activatePrefixes = ["activate ", "open ", "launch ", "switch to "]
  private static let terminatePrefixes = ["quit ", "terminate ", "close "]
  private static let shellPrefixes = ["run ", "execute "]

  public init() {}

  public func classify(normalized: String, raw: String) -> ClassificationResult {
    if let result = classifyCodingAgent(normalized) { return result }
    if let result = classifyAppCommand(
      normalized, prefixes: Self.activatePrefixes, kind: .appActivate,
      category: .appActivate)
    { return result }
    if let result = classifyAppCommand(
      normalized, prefixes: Self.terminatePrefixes, kind: .appTerminate,
      category: .appTerminate)
    { return result }
    if let result = classifyShellCommand(normalized) { return result }

    // No command pattern matched: treat as plain conversation. This is the
    // correct default, not a low-confidence fallback — most utterances an
    // assistant hears are just talk.
    return ClassificationResult(kind: .converse, semanticCategory: .converse, confidence: 0.9)
  }

  private func classifyCodingAgent(_ normalized: String) -> ClassificationResult? {
    for (prefix, backend) in Self.agentTriggers where normalized.hasPrefix(prefix) {
      let objective = String(normalized.dropFirst(prefix.count))
      guard !objective.isEmpty else { return nil }
      return ClassificationResult(
        kind: .codingAgentRun, semanticCategory: .codingAgentRun,
        slots: [
          IntentSlot(name: IntentSlotName.backend, value: backend),
          IntentSlot(name: IntentSlotName.objective, value: objective),
        ], confidence: 0.85)
    }
    for prefix in Self.genericAgentTriggers where normalized.hasPrefix(prefix) {
      let objective = String(normalized.dropFirst(prefix.count))
      guard !objective.isEmpty else { return nil }
      return ClassificationResult(
        kind: .codingAgentRun, semanticCategory: .codingAgentRun,
        slots: [IntentSlot(name: IntentSlotName.objective, value: objective)], confidence: 0.85)
    }
    return nil
  }

  private func classifyAppCommand(
    _ normalized: String, prefixes: [String], kind: IntentKind,
    category: IntentSemanticCategory
  ) -> ClassificationResult? {
    for prefix in prefixes where normalized.hasPrefix(prefix) {
      let appName = String(normalized.dropFirst(prefix.count)).trimmingCharacters(
        in: .whitespaces)
      guard !appName.isEmpty else { return nil }
      if let bundleID = Self.knownApplications[appName] {
        return ClassificationResult(
          kind: kind, semanticCategory: category,
          slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: bundleID)],
          confidence: 0.85)
      }
      // Recognized command shape, unrecognized app — genuinely ambiguous,
      // never a guessed bundle identifier.
      return ClassificationResult(
        kind: .unknown, semanticCategory: .unknown,
        slots: [IntentSlot(name: IntentSlotName.unresolvedAppName, value: appName)],
        confidence: 0.3)
    }
    return nil
  }

  private func classifyShellCommand(_ normalized: String) -> ClassificationResult? {
    for prefix in Self.shellPrefixes where normalized.hasPrefix(prefix) {
      let remainder = String(normalized.dropFirst(prefix.count)).trimmingCharacters(
        in: .whitespaces)
      guard !remainder.isEmpty else { return nil }
      let tokens = remainder.split(separator: " ").map(String.init)
      guard let first = tokens.first else { return nil }
      let arguments = Array(tokens.dropFirst())

      let executable: String?
      if first.hasPrefix("/") {
        executable = first
      } else {
        executable = Self.knownExecutables[first]
      }

      guard let resolvedExecutable = executable else {
        // Recognized command shape, unresolvable executable — ambiguous,
        // never a guessed path.
        return ClassificationResult(
          kind: .unknown, semanticCategory: .unknown,
          slots: [IntentSlot(name: IntentSlotName.executable, value: first)], confidence: 0.3)
      }

      return ClassificationResult(
        kind: .shellExecute, semanticCategory: .shellExecute,
        slots: [
          IntentSlot(name: IntentSlotName.executable, value: resolvedExecutable),
          IntentSlot(name: IntentSlotName.arguments, value: arguments.joined(separator: " ")),
        ], confidence: 0.85)
    }
    return nil
  }
}

/// Implements steps 1–6 of `docs/subsystems/08_INTENT_ENGINE.md`'s pipeline:
/// normalize → (classifier extracts entities/candidate) → confidence/
/// ambiguity gate → risk tier (always derived from `semanticCategory`,
/// never independently guessed). Steps 7–8 (select handler, produce an
/// inspectable execution plan) are `ToolRouter`'s responsibility.
public actor IntentEngine {
  private let classifier: any UtteranceClassifying
  private let contextEngine: ContextEngine?
  private let configuration: IntentEngineConfiguration
  private let eventBus: AuraEventBus

  public init(
    classifier: any UtteranceClassifying,
    contextEngine: ContextEngine? = nil,
    configuration: IntentEngineConfiguration = IntentEngineConfiguration(),
    eventBus: AuraEventBus
  ) {
    self.classifier = classifier
    self.contextEngine = contextEngine
    self.configuration = configuration
    self.eventBus = eventBus
  }

  /// Classify one completed conversational turn into a `TypedIntent`.
  /// Emits `IntentClassifiedEvent` unconditionally (including for `.unknown`
  /// results) — an ambiguous classification is itself audit-worthy.
  public func classify(
    _ turn: TurnCompletedEvent,
    correlationID: UUID,
    causationID: UUID
  ) async -> TypedIntent {
    let raw = turn.text
    let normalized = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let result = classifier.classify(normalized: normalized, raw: raw)

    let belowConfidence = result.confidence < configuration.minimumClassificationConfidence
    let isAmbiguous = belowConfidence || result.kind == .unknown
    let finalKind: IntentKind = isAmbiguous ? .unknown : result.kind
    let finalCategory: IntentSemanticCategory = isAmbiguous ? .unknown : result.semanticCategory

    let intent = TypedIntent(
      turnCorrelationID: correlationID,
      kind: finalKind,
      semanticCategory: finalCategory,
      rawUtterance: raw,
      normalizedUtterance: normalized,
      slots: result.slots,
      classificationConfidence: result.confidence,
      isAmbiguous: isAmbiguous
    )

    await emit(
      IntentClassifiedEvent(
        intentID: intent.id, turnCorrelationID: correlationID, kind: intent.kind.rawValue,
        semanticCategory: intent.semanticCategory, confidence: intent.classificationConfidence,
        isAmbiguous: intent.isAmbiguous, riskTier: intent.riskTier),
      correlationID: correlationID, causationID: causationID)

    return intent
  }

  private func emit<P: EventPayload>(_ payload: P, correlationID: UUID, causationID: UUID) async {
    let envelope = EventEnvelope(
      correlationID: correlationID, causationID: causationID, actor: .intent,
      sensitivity: .internalLevel, payload: payload)
    await eventBus.emit(envelope)
  }
}
