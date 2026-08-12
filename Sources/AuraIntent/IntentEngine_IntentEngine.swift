import AuraContext
import AuraCore
import AuraMemory
import Foundation

/// Implements steps 1–6 of `docs/subsystems/08_INTENT_ENGINE.md`'s pipeline:
/// normalize → (classifier extracts entities/candidate) → confidence/
/// ambiguity gate → risk tier (always derived from `semanticCategory`,
/// never independently guessed). Steps 7–8 (select handler, produce an
/// inspectable execution plan) are `ToolRouter`'s responsibility.
public actor IntentEngine {
  let classifier: any UtteranceClassifying
  let contextBuilder: ContextBuilder?
  let memoryEngine: MemoryEngine?
  let structuredNLUBackend: (any StructuredNLUBackend)?
  let configuration: IntentEngineConfiguration
  let eventBus: AuraEventBus
  let logger: AuraLogger
  let sessionID: UUID
  let now: @Sendable () -> Date
  var lastContextResult: DeepContextResult?
  var pendingClarification: PendingClarification?

  struct PendingClarification: Sendable {
    let kind: IntentKind
    let slotName: String
    let expiresAt: Date
  }

  public init(
    classifier: any UtteranceClassifying,
    contextEngine: ContextEngine? = nil,
    contextBuilder: ContextBuilder? = nil,
    memoryEngine: MemoryEngine? = nil,
    structuredNLUBackend: (any StructuredNLUBackend)? = nil,
    configuration: IntentEngineConfiguration = IntentEngineConfiguration(),
    eventBus: AuraEventBus,
    logger: AuraLogger = AuraLogger(subsystem: "AuraIntent", category: "intent-engine"),
    sessionID: UUID = UUID(),
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.classifier = classifier
    self.memoryEngine = memoryEngine
    self.structuredNLUBackend = structuredNLUBackend
    self.configuration = configuration
    self.eventBus = eventBus
    self.logger = logger
    self.sessionID = sessionID
    self.now = now
    if let contextBuilder {
      self.contextBuilder = contextBuilder
    } else if let contextEngine, let memoryEngine {
      self.contextBuilder = ContextBuilder(
        engine: contextEngine, memory: memoryEngine, eventBus: eventBus)
    } else {
      self.contextBuilder = nil
    }
  }

}
