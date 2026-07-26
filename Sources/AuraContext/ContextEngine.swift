import AuraCore
import AuraMemory
import AuraStore
import Foundation

/// Reconstructs the smallest sufficient context for one user utterance.
///
/// Follows the retrieval sequence from
/// `docs/subsystems/22_CONTEXT_RECONSTRUCTION.md`: current utterance →
/// conversation state → pending confirmation/task → active app/workspace →
/// project ledger → recent decisions → preferences → semantic retrieval.
///
/// The first four stages are transient, live subsystem state that
/// `ContextEngine` does not itself own (conversation state lives in
/// `AuraAgent.Conversation`, confirmations in `AuraPolicy.PolicyEngine`,
/// tasks in `AuraTasks.AuraTaskEngine`, workspace state in `AuraAutomation`/
/// `AuraVSCode`) — the caller passes in whatever it already has, and those
/// items are always included verbatim, never ranked away. The remaining
/// stages are this engine's own responsibility: it reads the project ledger
/// from `AuraStore` and preferences/facts from `AuraMemory`, ranks them by
/// scope match, recency, authority, confidence, and direct evidence
/// (`ContextRanking`), and truncates to a bounded budget.
public actor ContextEngine {
  private let store: AuraStore
  private let memory: MemoryEngine
  private let eventBus: AuraEventBus
  private let configuration: ContextConfiguration
  private let resolver: ReferenceResolver

  public init(
    store: AuraStore,
    memory: MemoryEngine,
    eventBus: AuraEventBus = .shared,
    configuration: ContextConfiguration = ContextConfiguration()
  ) {
    self.store = store
    self.memory = memory
    self.eventBus = eventBus
    self.configuration = configuration
    self.resolver = ReferenceResolver(configuration: configuration)
  }

  // MARK: - Context reconstruction

  /// Assemble a minimal, sufficient, source-traceable context bundle.
  @discardableResult
  public func reconstruct(
    utterance: String,
    sessionID: UUID,
    conversationState: ConversationState,
    pendingConfirmation: PolicyConfirmationChallenge? = nil,
    pendingTask: TaskStatus? = nil,
    activeWorkspace: ActiveWorkspaceSnapshot? = nil,
    scope: MemoryScope = .global,
    referenceDate: Date = Date(),
    actor: ActorID = .context,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> ContextBundle {
    var mandatory: [ContextItem] = []

    mandatory.append(
      ContextItem(
        stage: .currentUtterance, sourceID: .utterance, summary: utterance,
        authority: .userStated, confidence: 1.0, observedAt: referenceDate,
        hasDirectEvidence: true, scopeMatch: true))

    mandatory.append(
      ContextItem(
        stage: .conversationState, sourceID: .conversationState,
        summary: "conversation state: \(conversationState.rawValue)", authority: .systemDerived,
        confidence: 1.0, observedAt: referenceDate, hasDirectEvidence: true, scopeMatch: true))

    if let pendingConfirmation {
      mandatory.append(
        ContextItem(
          stage: .pendingConfirmationOrTask,
          sourceID: .pendingConfirmation(requestID: pendingConfirmation.requestID),
          summary:
            "pending confirmation: \(pendingConfirmation.requestedAction.identifier) on \(pendingConfirmation.targetSummary)",
          authority: .systemDerived, confidence: 1.0, observedAt: pendingConfirmation.issuedAt,
          hasDirectEvidence: true, scopeMatch: true))
    }
    if let pendingTask {
      mandatory.append(
        ContextItem(
          stage: .pendingConfirmationOrTask,
          sourceID: .pendingTask(taskID: pendingTask.id),
          summary: "pending task (\(pendingTask.state.rawValue)): \(pendingTask.objective)",
          authority: .systemDerived, confidence: 1.0, observedAt: pendingTask.updatedAt,
          hasDirectEvidence: true, scopeMatch: true))
    }

    if let activeWorkspace {
      mandatory.append(
        ContextItem(
          stage: .activeAppOrWorkspace, sourceID: .activeWorkspace,
          summary: activeWorkspace.summary, authority: .observed, confidence: 1.0,
          observedAt: activeWorkspace.capturedAt, hasDirectEvidence: true, scopeMatch: true))
    }

    let ledgerEntries = try await recentLedgerEntries()

    var candidates: [ContextItem] = []
    candidates.append(contentsOf: ledgerItems(from: ledgerEntries, referenceDate: referenceDate))
    candidates.append(contentsOf: decisionItems(from: ledgerEntries, referenceDate: referenceDate))
    candidates.append(
      contentsOf: try await preferenceItems(scope: scope, referenceDate: referenceDate))
    candidates.append(
      contentsOf: try await semanticItems(
        utterance: utterance, scope: scope, referenceDate: referenceDate))

    // Each category above is already ranked and capped by the same
    // composite score (`rankAndCap`); a final global sort + budget cut
    // selects the overall "minimal and sufficient" set across categories.
    let ranked = candidates.sorted { $0.score > $1.score }
    let kept = Array(ranked.prefix(configuration.maxBundleItems))
    let droppedCount = candidates.count - kept.count

    // Present the kept optional items back in retrieval-sequence order.
    let orderedTail = kept.sorted { $0.stage == $1.stage ? $0.score > $1.score : $0.stage < $1.stage }

    let bundle = ContextBundle(
      sessionID: sessionID, utterance: utterance, generatedAt: referenceDate,
      items: mandatory + orderedTail, consideredCandidateCount: candidates.count,
      droppedCandidateCount: droppedCount)

    await emit(
      ContextBundleAssembledEvent(
        sessionID: sessionID, itemCount: bundle.items.count,
        consideredCandidateCount: bundle.consideredCandidateCount,
        droppedCandidateCount: bundle.droppedCandidateCount, assembledAt: referenceDate),
      actor: actor, correlationID: correlationID)

    return bundle
  }

  // MARK: - Reference resolution

  /// Resolve an implicit reference ("it", "that", "the file") against a set
  /// of candidate targets, emitting an audit event for every outcome —
  /// including a resolution deliberately blocked for weak evidence, which is
  /// the mechanically-enforced proof that "it" never silently resolves to a
  /// destructive target on weak evidence.
  public func resolveReference(
    _ reference: String,
    candidates: [ReferenceCandidate],
    referenceDate: Date = Date(),
    actor: ActorID = .context,
    correlationID: UUID = UUID()
  ) async -> ReferenceResolution {
    let resolution = resolver.resolve(
      reference: reference, candidates: candidates, referenceDate: referenceDate)

    let event: ReferenceResolutionEvent
    switch resolution {
    case .resolved(let candidate):
      event = ReferenceResolutionEvent(
        reference: reference, outcome: .resolved, candidateCount: candidates.count,
        targetSummary: candidate.description, riskTier: candidate.capability?.riskTier,
        resolvedAt: referenceDate)
    case .ambiguous(let ranked):
      event = ReferenceResolutionEvent(
        reference: reference, outcome: .ambiguous, candidateCount: ranked.count,
        resolvedAt: referenceDate)
    case .blockedWeakEvidence(let candidate):
      event = ReferenceResolutionEvent(
        reference: reference, outcome: .blockedWeakEvidence, candidateCount: candidates.count,
        targetSummary: candidate.description, riskTier: candidate.capability?.riskTier,
        resolvedAt: referenceDate)
    case .none:
      event = ReferenceResolutionEvent(
        reference: reference, outcome: .none, candidateCount: 0, resolvedAt: referenceDate)
    }
    await emit(event, actor: actor, correlationID: correlationID)
    return resolution
  }

  // MARK: - Ledger stages

  /// `AuraStore.entries(limit:)` orders ascending and applies `LIMIT` from
  /// the start of that order, so without a large-enough limit it returns the
  /// OLDEST rows, not the most recent ones. Fetch a generous ceiling
  /// (effectively "all" for any realistic ledger size, without an
  /// unbounded query) and take the true tail, so "recent" actually means
  /// recent regardless of how many entries have accumulated.
  private static let ledgerFetchCeiling = 100_000

  private func recentLedgerEntries() async throws(AuraError) -> [ProjectLedgerEntry] {
    let all = try await store.entries(limit: Self.ledgerFetchCeiling)
    return Array(all.suffix(max(configuration.maxLedgerEntries * 4, 20)))
  }

  private func ledgerItems(from entries: [ProjectLedgerEntry], referenceDate: Date) -> [ContextItem]
  {
    let items = entries.map { entry -> ContextItem in
      let title = entry.title.isEmpty ? entry.currentState : entry.title
      return ContextItem(
        stage: .projectLedger, sourceID: .projectLedgerEntry(entryID: entry.id),
        summary: entry.taskID.isEmpty ? title : "\(entry.taskID): \(title)",
        authority: .systemDerived, confidence: 1.0, observedAt: entry.timestamp,
        hasDirectEvidence: !entry.evidenceInspected.isEmpty || !entry.filesChanged.isEmpty,
        scopeMatch: true)
    }
    return rankAndCap(items, limit: configuration.maxLedgerEntries, referenceDate: referenceDate)
  }

  private func decisionItems(from entries: [ProjectLedgerEntry], referenceDate: Date)
    -> [ContextItem]
  {
    var items: [ContextItem] = []
    for entry in entries {
      for (index, decision) in entry.decisions.enumerated() {
        items.append(
          ContextItem(
            stage: .recentDecisions, sourceID: .decision(entryID: entry.id, index: index),
            summary: decision, authority: .systemDerived, confidence: 0.9,
            observedAt: entry.timestamp, hasDirectEvidence: !entry.evidenceInspected.isEmpty,
            scopeMatch: true))
      }
    }
    return rankAndCap(items, limit: configuration.maxDecisions, referenceDate: referenceDate)
  }

  private func preferenceItems(scope: MemoryScope, referenceDate: Date) async throws(AuraError)
    -> [ContextItem]
  {
    let records = try await memory.currentState(memoryClass: .userPreference, scope: nil)
    let items = records.map { record in
      ContextItem(
        stage: .preferences, sourceID: .memoryRecord(recordID: record.id),
        summary: record.statement, authority: ContextAuthority.from(record.provenance),
        confidence: record.confidence, observedAt: record.observedAt,
        hasDirectEvidence: !record.evidenceReferences.isEmpty,
        scopeMatch: ContextRanking.scopeMatches(recordScope: record.scope, requestScope: scope))
    }
    return rankAndCap(items, limit: configuration.maxPreferences, referenceDate: referenceDate)
  }

  private func semanticItems(utterance: String, scope: MemoryScope, referenceDate: Date)
    async throws(AuraError) -> [ContextItem]
  {
    let queryTokens = ContextRanking.tokenize(utterance)
    guard !queryTokens.isEmpty else { return [] }

    let classes: [MemoryClass] = [.projectFact, .proceduralKnowledge, .taskState]
    var items: [ContextItem] = []
    for memoryClass in classes {
      let records = try await memory.currentState(memoryClass: memoryClass, scope: nil)
      for record in records {
        let documentTokens = ContextRanking.tokenize("\(record.subject) \(record.statement)")
        let overlap = ContextRanking.containmentScore(query: queryTokens, document: documentTokens)
        guard overlap >= configuration.semanticMatchMinimumOverlap else { continue }
        items.append(
          ContextItem(
            stage: .semanticRetrieval, sourceID: .memoryRecord(recordID: record.id),
            summary: record.statement, authority: ContextAuthority.from(record.provenance),
            confidence: record.confidence, observedAt: record.observedAt,
            hasDirectEvidence: !record.evidenceReferences.isEmpty,
            scopeMatch: ContextRanking.scopeMatches(
              recordScope: record.scope, requestScope: scope)))
      }
    }
    return rankAndCap(items, limit: configuration.maxSemanticMatches, referenceDate: referenceDate)
  }

  /// Score every item with the shared composite ranking function and keep
  /// only the top `limit` — the same scoring rule used for this per-category
  /// cap is used again for the final cross-category budget cut in
  /// `reconstruct`, so scope/authority/confidence/evidence actually influence
  /// which candidates survive every truncation point, not just the last one.
  private func rankAndCap(_ items: [ContextItem], limit: Int, referenceDate: Date) -> [ContextItem]
  {
    items
      .map {
        $0.withScore(ContextRanking.score($0, referenceDate: referenceDate, configuration: configuration))
      }
      .sorted { $0.score > $1.score }
      .prefix(limit)
      .map { $0 }
  }

  // MARK: - Event emission

  private func emit<Payload: EventPayload>(
    _ payload: Payload, actor: ActorID, correlationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID, causationID: correlationID, actor: actor,
      sensitivity: .internalLevel, payload: payload)
    await eventBus.emit(envelope)
  }
}
