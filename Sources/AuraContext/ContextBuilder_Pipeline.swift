import AuraCore
import AuraMemory
import Foundation

extension ContextBuilder {
  // MARK: - Pipeline stages

  func parse(_ utterance: String) -> ParsedContextUtterance {
    let normalized = utterance.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let tokens = ContextRanking.tokenize(normalized).sorted()
    let reference = ImplicitReferencePhrases.firstMatch(in: normalized)
    return ParsedContextUtterance(
      normalized: normalized, tokens: tokens, implicitReference: reference)
  }

  func containsPhrase(_ text: String, phrase: String) -> Bool {
    ImplicitReferencePhrases.contains(text, phrase: phrase)
  }

  func applyingIntentCapability(
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

  func extractEntities(
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

  func entityKind(for label: String) -> ReferenceEntityKind {
    let lower = label.lowercased()
    if lower.contains("file") || lower.contains("/") { return .file }
    if lower.contains("repo") || lower.contains("repository") || lower.contains("workspace") {
      return .repository
    }
    if lower.contains("task") { return .task }
    if lower.contains("test") { return .test }
    if lower.contains("draft") { return .draft }
    if lower.contains("claude") || lower.contains("codex") || lower.contains("copilot") {
      return .backend
    }
    if lower.contains("decision") { return .decision }
    if lower.contains("preference") { return .preference }
    return .unknown
  }

  struct Enrichment {
    let items: [ContextItem]
    let graphItems: [ContextItem]
  }

  func enrichWithProvenance(
    _ sourceItems: [ContextItem],
    scope: MemoryScope,
    includedRecordIDs: Set<UUID>,
    referenceDate: Date
  ) async throws(AuraError) -> Enrichment {
    let catalog = try await enrichmentCatalog()
    var items = sourceItems.filter { item in
      guard case .memoryRecord(let recordID) = item.sourceID else { return true }
      return catalog.recordByID[recordID]?.sensitivity != .secret
    }
    appendIncludedRecords(
      to: &items, catalog: catalog, includedRecordIDs: includedRecordIDs,
      scope: scope, referenceDate: referenceDate)
    let graphItems = try await appendGraphItems(
      to: &items, referenceDate: referenceDate)
    return Enrichment(items: items, graphItems: graphItems)
  }

  private struct EnrichmentCatalog {
    let recordByID: [UUID: MemoryRecord]
    let activeRecordByID: [UUID: MemoryRecord]
  }

  private func enrichmentCatalog() async throws(AuraError) -> EnrichmentCatalog {
    let currentRecords = try await memory.inspect(includeSuperseded: false)
    let activeIDs = Set((try await memory.activeBeliefs()).map(\.activeRecordID))
    return EnrichmentCatalog(
      recordByID: Dictionary(uniqueKeysWithValues: currentRecords.map { ($0.id, $0) }),
      activeRecordByID: Dictionary(
        uniqueKeysWithValues: currentRecords.filter { activeIDs.contains($0.id) }
          .map { ($0.id, $0) }))
  }

  private func appendIncludedRecords(
    to items: inout [ContextItem],
    catalog: EnrichmentCatalog,
    includedRecordIDs: Set<UUID>,
    scope: MemoryScope,
    referenceDate: Date
  ) {
    let injectableClasses: Set<MemoryClass> = [
      .projectFact, .userPreference, .proceduralKnowledge, .taskState, .sessionSummary,
    ]
    for recordID in includedRecordIDs {
      guard let record = catalog.activeRecordByID[recordID],
        injectableClasses.contains(record.memoryClass), record.sensitivity != .secret,
        ContextRanking.scopeMatches(recordScope: record.scope, requestScope: scope),
        !items.contains(where: { $0.sourceID == .memoryRecord(recordID: recordID) })
      else {
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
            configuration: configuration), inclusionReason: "explicit per-turn inclusion override"))
    }
  }

  private func appendGraphItems(
    to items: inout [ContextItem], referenceDate: Date
  ) async throws(AuraError) -> [ContextItem] {
    var graphItems: [ContextItem] = []
    var seenNodes = Set<UUID>()
    for index in items.indices {
      guard case .memoryRecord(let recordID) = items[index].sourceID else { continue }
      let subgraph = try await memory.provenance(
        for: recordID, maxDepth: configuration.maxGraphDepth)
      let nodeIDs = subgraph.nodes.map(\.id)
      items[index] = items[index].withExplainability(
        provenanceNodeIDs: nodeIDs,
        inclusionReason: items[index].inclusionReason == "explicit per-turn inclusion override"
          ? items[index].inclusionReason
          : "ranked memory with \(nodeIDs.count) provenance node(s)")
      for node in subgraph.nodes where seenNodes.insert(node.id).inserted {
        graphItems.append(
          graphItem(
            node: node, recordID: recordID, subgraph: subgraph,
            referenceDate: referenceDate))
      }
    }
    return Array(graphItems.sorted { $0.score > $1.score }.prefix(configuration.maxGraphItems))
  }

  private func graphItem(
    node: ProvenanceNode, recordID: UUID, subgraph: ProvenanceSubgraph, referenceDate: Date
  ) -> ContextItem {
    let hasEvidence = subgraph.edges.contains {
      $0.sourceID == node.id || $0.targetID == node.id
    }
    let item = ContextItem(
      stage: .semanticRetrieval, sourceID: .provenanceNode(nodeID: node.id), summary: node.label,
      authority: contextAuthority(node.authority), confidence: node.confidence,
      observedAt: node.createdAt, hasDirectEvidence: hasEvidence, scopeMatch: true,
      provenanceNodeIDs: [node.id],
      inclusionReason: "multi-hop provenance relation from memory record \(recordID)")
    return item.withScore(
      ContextRanking.score(item, referenceDate: referenceDate, configuration: configuration)
        + graphKindBoost(node.kind))
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

  func contextAuthority(_ authority: ProvenanceAuthority) -> ContextAuthority {
    switch authority {
    case .userConfirmed, .userStated: return .userStated
    case .derivedPolicy, .derivedTool: return .systemDerived
    case .inferred: return .inferred
    }
  }

  func graphKindBoost(_ kind: ProvenanceNodeKind) -> Double {
    switch kind {
    case .file, .task, .decision, .preference: return 0.04
    case .fact, .utterance: return 0
    }
  }

  func budget(
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

  func isForced(_ sourceID: ContextSourceID, forcedRecordIDs: Set<UUID>) -> Bool {
    guard case .memoryRecord(let id) = sourceID else { return false }
    return forcedRecordIDs.contains(id)
  }

  /// Conservative, tokenizer-free local estimate: four UTF-8 bytes per
  /// token plus a small per-item structural allowance.
  public static func estimateTokens(_ text: String) -> Int {
    max(1, Int(ceil(Double(text.utf8.count) / 4.0)) + 6)
  }

  func resolutionDescription(_ resolution: ReferenceResolution) -> String {
    switch resolution {
    case .resolved: return "resolved"
    case .ambiguous: return "ambiguous"
    case .blockedWeakEvidence: return "blocked weak evidence"
    case .none: return "no reference resolution requested"
    }
  }

  func emit<P: EventPayload>(
    _ payload: P, actor: ActorID, correlationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID, causationID: correlationID, actor: actor,
      sensitivity: .internalLevel,
      payload: payload)
    await eventBus.emit(envelope)
  }
}
