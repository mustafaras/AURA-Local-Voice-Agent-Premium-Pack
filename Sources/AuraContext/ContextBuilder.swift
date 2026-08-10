import AuraCore
import AuraMemory
import Foundation

/// Phase 22's bounded, inspectable context pipeline.
///
/// The builder composes (rather than replaces) Phase 16 `ContextEngine`.
/// It adds typed parsing/schema/entity stages, provenance-graph expansion,
/// reference-graph resolution, per-turn inclusion overrides, and a hard
/// local token estimate. It never evaluates policy or authorizes an action.
public actor ContextBuilder {
  private let engine: ContextEngine
  private let memory: MemoryEngine
  private let eventBus: AuraEventBus
  private let configuration: ContextConfiguration
  private let resolver: ReferenceResolver

  public init(
    engine: ContextEngine,
    memory: MemoryEngine,
    eventBus: AuraEventBus = .shared,
    configuration: ContextConfiguration = ContextConfiguration()
  ) {
    self.engine = engine
    self.memory = memory
    self.eventBus = eventBus
    self.configuration = configuration
    self.resolver = ReferenceResolver(configuration: configuration)
  }

  public func build(
    _ request: DeepContextRequest,
    actor: ActorID = .context,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> DeepContextResult {
    try configuration.validate()
    if request.deliveryPolicy.destination == .remoteModel
      && !request.deliveryPolicy.permits(.sensitive)
    {
      throw AuraError.contextError(
        "remote context requires a separately redacted, user-approved turn summary")
    }
    let startedAt = Date()
    var trace: [ContextPipelineTrace] = []

    let parsed = parse(request.utterance)
    trace.append(
      ContextPipelineTrace(
        stage: .utteranceParse, inputCount: 1, outputCount: parsed.tokens.count,
        detail: parsed.implicitReference.map { "implicit reference: \($0)" }
          ?? "no implicit reference"))
    trace.append(
      ContextPipelineTrace(
        stage: .intentSchema, inputCount: 1, outputCount: 1,
        detail: "\(request.intent.name), confidence \(request.intent.confidence)"))

    var baseBundle = try await engine.reconstruct(
      utterance: request.utterance,
      sessionID: request.sessionID,
      purpose: request.purpose,
      requestingComponent: request.requestingComponent,
      conversationState: request.conversationState,
      pendingConfirmation: request.pendingConfirmation,
      pendingTask: request.pendingTask,
      activeWorkspace: request.activeWorkspace,
      scope: request.scope,
      referenceDate: request.referenceDate,
      deliveryPolicy: request.deliveryPolicy,
      actor: actor,
      correlationID: correlationID)

    let enriched = try await enrichWithProvenance(
      baseBundle.items, scope: request.scope,
      includedRecordIDs: request.inclusionOverride.includedMemoryRecordIDs,
      referenceDate: request.referenceDate)
    var allItems = (enriched.items + enriched.graphItems).map { item in
      guard !item.stage.isMandatory, item.inclusionReason == "mandatory live context" else {
        return item
      }
      return item.withExplainability(
        provenanceNodeIDs: item.provenanceNodeIDs,
        inclusionReason:
          "ranked \(String(describing: item.stage)) context; score \(item.score)")
    }

    let entities = extractEntities(
      request: request, items: allItems, referenceCandidates: request.referenceCandidates)
    trace.append(
      ContextPipelineTrace(
        stage: .entityExtraction, inputCount: allItems.count, outputCount: entities.count,
        detail: "typed entities from workspace, references, and provenance"))

    let inScopeCount = request.referenceCandidates.filter(\.scopeMatch).count
    trace.append(
      ContextPipelineTrace(
        stage: .scopeFilter, inputCount: request.referenceCandidates.count,
        outputCount: inScopeCount,
        detail: "out-of-scope action candidates retained only so the resolver can block them"))

    let referenceGraph: ReferenceResolutionGraph?
    let referenceResolution: ReferenceResolution
    if let reference = parsed.implicitReference {
      let candidates = request.referenceCandidates.map {
        applyingIntentCapability($0, capability: request.intent.capability)
      }
      referenceGraph = resolver.graph(
        reference: reference, candidates: candidates, referenceDate: request.referenceDate,
        explicitlyConfirmedTargetID: request.explicitlyConfirmedTargetID)
      referenceResolution = resolver.resolve(
        reference: reference, candidates: candidates, referenceDate: request.referenceDate,
        explicitlyConfirmedTargetID: request.explicitlyConfirmedTargetID)
    } else {
      referenceGraph = nil
      referenceResolution = .none
    }
    trace.append(
      ContextPipelineTrace(
        stage: .evidenceRank, inputCount: request.referenceCandidates.count,
        outputCount: referenceGraph?.nodes.count ?? 0,
        detail: "scope, recency, authority, confidence, evidence, and salience ranked"))
    trace.append(
      ContextPipelineTrace(
        stage: .ambiguityCheck, inputCount: referenceGraph?.nodes.count ?? 0,
        outputCount: referenceResolution == .none ? 0 : 1,
        detail: resolutionDescription(referenceResolution)))

    var exclusions = baseBundle.exclusions

    // Mandatory live context cannot be hidden by an override. Optional
    // exclusions are applied before token selection.
    allItems.removeAll {
      let excluded =
        !$0.stage.isMandatory
        && request.inclusionOverride.excludedSourceIDs.contains($0.sourceID)
      if excluded {
        exclusions.append("excluded by per-turn user override: \($0.sourceID)")
      }
      return excluded
    }

    let budgeted = try budget(
      items: allItems,
      forcedRecordIDs: request.inclusionOverride.includedMemoryRecordIDs,
      maxTokens: configuration.maxTokenBudget)
    baseBundle = ContextBundle(
      sessionID: baseBundle.sessionID,
      utterance: baseBundle.utterance,
      purpose: baseBundle.purpose,
      requestingComponent: baseBundle.requestingComponent,
      deliveryPolicy: baseBundle.deliveryPolicy,
      generatedAt: baseBundle.generatedAt,
      items: budgeted.items.sorted {
        $0.stage == $1.stage ? $0.score > $1.score : $0.stage < $1.stage
      },
      consideredCandidateCount: baseBundle.consideredCandidateCount + enriched.graphItems.count,
      droppedCandidateCount:
        baseBundle.droppedCandidateCount + max(0, allItems.count - budgeted.items.count),
      tokenBudget: configuration.maxTokenBudget,
      estimatedTokenCount: budgeted.tokens,
      exclusions: exclusions,
      unresolvedContradictions: baseBundle.unresolvedContradictions)

    let inspection = baseBundle.items.map {
      ContextInspectionItem(item: $0, estimatedTokens: Self.estimateTokens($0.summary))
    }
    trace.append(
      ContextPipelineTrace(
        stage: .finalBundle, inputCount: allItems.count, outputCount: baseBundle.items.count,
        detail: "\(budgeted.tokens)/\(configuration.maxTokenBudget) estimated tokens"))

    let elapsed = Date().timeIntervalSince(startedAt)
    let result = DeepContextResult(
      parsedUtterance: parsed, intent: request.intent, entities: entities,
      referenceGraph: referenceGraph, referenceResolution: referenceResolution,
      bundle: baseBundle, inspection: inspection, trace: trace,
      estimatedTokenCount: budgeted.tokens, elapsedSeconds: elapsed)

    await emit(
      DeepContextBuiltEvent(
        sessionID: request.sessionID, itemCount: baseBundle.items.count,
        estimatedTokenCount: budgeted.tokens, tokenBudget: configuration.maxTokenBudget,
        elapsedSeconds: elapsed,
        latencyBudgetSeconds: configuration.lookupLatencyBudgetSeconds,
        metLatencyBudget: elapsed <= configuration.lookupLatencyBudgetSeconds),
      actor: actor, correlationID: correlationID)
    return result
  }

  // MARK: - Pipeline stages

  private func parse(_ utterance: String) -> ParsedContextUtterance {
    let normalized = utterance.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let tokens = ContextRanking.tokenize(normalized).sorted()
    let phrases = ["the last one", "the file", "the document", "the app", "that", "it"]
    let reference = phrases.first { containsPhrase(normalized, phrase: $0) }
    return ParsedContextUtterance(
      normalized: normalized, tokens: tokens, implicitReference: reference)
  }

  private func containsPhrase(_ text: String, phrase: String) -> Bool {
    if phrase.contains(" ") { return text.contains(phrase) }
    let words = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    return words.contains(phrase)
  }

  private func applyingIntentCapability(
    _ candidate: ReferenceCandidate, capability: Capability?
  ) -> ReferenceCandidate {
    guard candidate.capability == nil, let capability else { return candidate }
    return ReferenceCandidate(
      id: candidate.id, sourceID: candidate.sourceID, description: candidate.description,
      capability: capability, authority: candidate.authority, confidence: candidate.confidence,
      observedAt: candidate.observedAt, hasDirectEvidence: candidate.hasDirectEvidence,
      scopeMatch: candidate.scopeMatch, entityKind: candidate.entityKind,
      conversationalSalience: candidate.conversationalSalience,
      provenanceNodeIDs: candidate.provenanceNodeIDs)
  }

  private func extractEntities(
    request: DeepContextRequest,
    items: [ContextItem],
    referenceCandidates: [ReferenceCandidate]
  ) -> [ExtractedContextEntity] {
    var result = referenceCandidates.map {
      ExtractedContextEntity(
        id: $0.id, kind: $0.entityKind, label: $0.description, sourceID: $0.sourceID,
        provenanceNodeIDs: $0.provenanceNodeIDs, confidence: $0.confidence)
    }
    if let path = request.activeWorkspace?.activeFilePath {
      result.append(
        ExtractedContextEntity(
          kind: .file, label: path, sourceID: .activeWorkspace, confidence: 1))
    }
    for item in items {
      guard case .provenanceNode = item.sourceID else { continue }
      result.append(
        ExtractedContextEntity(
          kind: entityKind(for: item.summary), label: item.summary, sourceID: item.sourceID,
          provenanceNodeIDs: item.provenanceNodeIDs, confidence: item.confidence))
    }
    return result
  }

  private func entityKind(for label: String) -> ReferenceEntityKind {
    let lower = label.lowercased()
    if lower.contains("file") || lower.contains("/") { return .file }
    if lower.contains("task") { return .task }
    if lower.contains("decision") { return .decision }
    if lower.contains("preference") { return .preference }
    return .unknown
  }

  private struct Enrichment {
    let items: [ContextItem]
    let graphItems: [ContextItem]
  }

  private func enrichWithProvenance(
    _ sourceItems: [ContextItem],
    scope: MemoryScope,
    includedRecordIDs: Set<UUID>,
    referenceDate: Date
  ) async throws(AuraError) -> Enrichment {
    var items = sourceItems
    let currentRecords = try await memory.inspect(includeSuperseded: false)
    let beliefs = try await memory.activeBeliefs()
    let activeIDs = Set(beliefs.map(\.activeRecordID))
    let recordByID = Dictionary(uniqueKeysWithValues: currentRecords.map { ($0.id, $0) })
    let activeRecordByID = Dictionary(
      uniqueKeysWithValues: currentRecords.filter { activeIDs.contains($0.id) }.map { ($0.id, $0) })
    items.removeAll { item in
      guard case .memoryRecord(let recordID) = item.sourceID else { return false }
      return recordByID[recordID]?.sensitivity == .secret
    }
    let injectableClasses: Set<MemoryClass> = [
      .projectFact, .userPreference, .proceduralKnowledge, .taskState, .sessionSummary,
    ]

    for recordID in includedRecordIDs {
      guard let record = activeRecordByID[recordID] else { continue }
      guard injectableClasses.contains(record.memoryClass), record.sensitivity != .secret else {
        continue
      }
      guard ContextRanking.scopeMatches(recordScope: record.scope, requestScope: scope) else {
        continue
      }
      guard !items.contains(where: { $0.sourceID == .memoryRecord(recordID: recordID) }) else {
        continue
      }
      items.append(
        ContextItem(
          stage: record.memoryClass == .userPreference ? .preferences : .semanticRetrieval,
          sourceID: .memoryRecord(recordID: record.id), summary: record.statement,
          authority: ContextAuthority.from(record.provenance), confidence: record.confidence,
          observedAt: record.observedAt, hasDirectEvidence: !record.evidenceReferences.isEmpty,
          scopeMatch: true, sensitivity: record.sensitivity,
          score: ContextRanking.score(
            MemoryRankable(record: record), referenceDate: referenceDate,
            configuration: configuration),
          inclusionReason: "explicit per-turn inclusion override"))
    }

    var graphItems: [ContextItem] = []
    var seenNodes = Set<UUID>()
    for index in items.indices {
      guard case .memoryRecord(let recordID) = items[index].sourceID else { continue }
      let subgraph = try await memory.provenance(
        for: recordID, maxDepth: configuration.maxGraphDepth)
      let nodeIDs = subgraph.nodes.map(\.id)
      items[index] = items[index].withExplainability(
        provenanceNodeIDs: nodeIDs,
        inclusionReason:
          items[index].inclusionReason == "explicit per-turn inclusion override"
          ? items[index].inclusionReason
          : "ranked memory with \(nodeIDs.count) provenance node(s)")

      for node in subgraph.nodes where seenNodes.insert(node.id).inserted {
        let hasEvidence = subgraph.edges.contains {
          $0.sourceID == node.id || $0.targetID == node.id
        }
        let item = ContextItem(
          stage: .semanticRetrieval, sourceID: .provenanceNode(nodeID: node.id),
          summary: node.label, authority: contextAuthority(node.authority),
          confidence: node.confidence, observedAt: node.createdAt,
          hasDirectEvidence: hasEvidence, scopeMatch: true,
          provenanceNodeIDs: [node.id],
          inclusionReason: "multi-hop provenance relation from memory record \(recordID)")
        graphItems.append(
          item.withScore(
            ContextRanking.score(
              item, referenceDate: referenceDate, configuration: configuration)
              + graphKindBoost(node.kind)))
      }
    }
    graphItems = Array(
      graphItems.sorted { $0.score > $1.score }.prefix(configuration.maxGraphItems))
    return Enrichment(items: items, graphItems: graphItems)
  }

  private struct MemoryRankable: ContextRankable {
    let observedAt: Date
    let authority: ContextAuthority
    let confidence: Double
    let hasDirectEvidence: Bool
    let scopeMatch: Bool

    init(record: MemoryRecord) {
      observedAt = record.observedAt
      authority = ContextAuthority.from(record.provenance)
      confidence = record.confidence
      hasDirectEvidence = !record.evidenceReferences.isEmpty
      scopeMatch = true
    }
  }

  private func contextAuthority(_ authority: ProvenanceAuthority) -> ContextAuthority {
    switch authority {
    case .userConfirmed, .userStated: return .userStated
    case .derivedPolicy, .derivedTool: return .systemDerived
    case .inferred: return .inferred
    }
  }

  private func graphKindBoost(_ kind: ProvenanceNodeKind) -> Double {
    switch kind {
    case .file, .task, .decision, .preference: return 0.04
    case .fact, .utterance: return 0
    }
  }

  private func budget(
    items: [ContextItem], forcedRecordIDs: Set<UUID>, maxTokens: Int
  ) throws(AuraError) -> (items: [ContextItem], tokens: Int) {
    let mandatory = items.filter(\.stage.isMandatory)
    var used = mandatory.reduce(0) { $0 + Self.estimateTokens($1.summary) }
    guard used <= maxTokens else {
      throw AuraError.contextError(
        "mandatory live context requires \(used) estimated tokens, exceeding budget \(maxTokens)")
    }

    let optional = items.filter { !$0.stage.isMandatory }.sorted { lhs, rhs in
      let lhsForced = isForced(lhs.sourceID, forcedRecordIDs: forcedRecordIDs)
      let rhsForced = isForced(rhs.sourceID, forcedRecordIDs: forcedRecordIDs)
      if lhsForced != rhsForced { return lhsForced }
      if lhs.score != rhs.score { return lhs.score > rhs.score }
      return String(describing: lhs.sourceID) < String(describing: rhs.sourceID)
    }

    var kept = mandatory
    for item in optional {
      let cost = Self.estimateTokens(item.summary)
      guard used + cost <= maxTokens else { continue }
      kept.append(item)
      used += cost
    }
    return (kept, used)
  }

  private func isForced(_ sourceID: ContextSourceID, forcedRecordIDs: Set<UUID>) -> Bool {
    guard case .memoryRecord(let id) = sourceID else { return false }
    return forcedRecordIDs.contains(id)
  }

  /// Conservative, tokenizer-free local estimate: four UTF-8 bytes per
  /// token plus a small per-item structural allowance.
  public static func estimateTokens(_ text: String) -> Int {
    max(1, Int(ceil(Double(text.utf8.count) / 4.0)) + 6)
  }

  private func resolutionDescription(_ resolution: ReferenceResolution) -> String {
    switch resolution {
    case .resolved: return "resolved"
    case .ambiguous: return "ambiguous"
    case .blockedWeakEvidence: return "blocked weak evidence"
    case .none: return "no reference resolution requested"
    }
  }

  private func emit<P: EventPayload>(
    _ payload: P, actor: ActorID, correlationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID, causationID: correlationID, actor: actor,
      sensitivity: .internalLevel,
      payload: payload)
    await eventBus.emit(envelope)
  }
}
