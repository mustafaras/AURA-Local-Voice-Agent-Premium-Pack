import AuraCore
import AuraMemory
import Foundation

private struct ContextBuildPreparation {
  let parsed: ParsedContextUtterance
  let baseBundle: ContextBundle
  let allItems: [ContextItem]
  let graphItemCount: Int
  let entities: [ExtractedContextEntity]
  let referenceGraph: ReferenceResolutionGraph?
  let referenceResolution: ReferenceResolution
  let trace: [ContextPipelineTrace]
}

private typealias ContextBudgetResult = (items: [ContextItem], tokens: Int)

private struct ContextBuildMetadata {
  let entities: [ExtractedContextEntity]
  let referenceGraph: ReferenceResolutionGraph?
  let referenceResolution: ReferenceResolution
  let trace: [ContextPipelineTrace]
}

extension ContextBuilder {
  public func build(
    _ request: DeepContextRequest,
    actor: ActorID = .context,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> DeepContextResult {
    let startedAt = Date()
    let preparation = try await prepareBuild(
      request, actor: actor, correlationID: correlationID)
    return try await finalizeBuild(
      preparation, request: request, actor: actor, correlationID: correlationID,
      startedAt: startedAt)
  }

  private func prepareBuild(
    _ request: DeepContextRequest,
    actor: ActorID,
    correlationID: UUID
  ) async throws(AuraError) -> ContextBuildPreparation {
    try configuration.validate()
    guard
      request.deliveryPolicy.destination != .remoteModel
        || request.deliveryPolicy.permits(.sensitive)
    else {
      throw AuraError.contextError(
        "remote context requires a separately redacted, user-approved turn summary")
    }
    let parsed = parse(request.utterance)
    let initialTrace = [
      ContextPipelineTrace(
        stage: .utteranceParse, inputCount: 1, outputCount: parsed.tokens.count,
        detail: parsed.implicitReference.map { "implicit reference: \($0)" }
          ?? "no implicit reference"),
      ContextPipelineTrace(
        stage: .intentSchema, inputCount: 1, outputCount: 1,
        detail: "\(request.intent.name), "
          + "confidence \(request.intent.confidence)"),
    ]
    let baseBundle = try await engine.reconstruct(
      utterance: request.utterance, sessionID: request.sessionID, purpose: request.purpose,
      requestingComponent: request.requestingComponent,
      conversationState: request.conversationState,
      pendingConfirmation: request.pendingConfirmation,
      pendingTask: request.pendingTask, activeWorkspace: request.activeWorkspace,
      scope: request.scope, referenceDate: request.referenceDate,
      deliveryPolicy: request.deliveryPolicy, actor: actor, correlationID: correlationID)
    let enriched = try await enrichWithProvenance(
      baseBundle.items, scope: request.scope,
      includedRecordIDs: request.inclusionOverride.includedMemoryRecordIDs,
      referenceDate: request.referenceDate)
    let allItems = (enriched.items + enriched.graphItems).map { item in
      guard !item.stage.isMandatory, item.inclusionReason == "mandatory live context" else {
        return item
      }
      return item.withExplainability(
        provenanceNodeIDs: item.provenanceNodeIDs,
        inclusionReason:
          "ranked \(String(describing: item.stage)) context; score \(item.score)")
    }
    let metadata = buildMetadata(request: request, parsed: parsed, items: allItems)
    return ContextBuildPreparation(
      parsed: parsed, baseBundle: baseBundle, allItems: allItems,
      graphItemCount: enriched.graphItems.count, entities: metadata.entities,
      referenceGraph: metadata.referenceGraph, referenceResolution: metadata.referenceResolution,
      trace: initialTrace + metadata.trace)
  }

  private func buildMetadata(
    request: DeepContextRequest,
    parsed: ParsedContextUtterance,
    items: [ContextItem]
  ) -> ContextBuildMetadata {
    let entities = extractEntities(
      request: request, items: items, referenceCandidates: request.referenceCandidates)
    let (referenceGraph, referenceResolution) = resolveReference(parsed: parsed, request: request)
    let trace = [
      ContextPipelineTrace(
        stage: .entityExtraction, inputCount: items.count, outputCount: entities.count,
        detail: "typed entities from workspace, references, and provenance"),
      ContextPipelineTrace(
        stage: .scopeFilter, inputCount: request.referenceCandidates.count,
        outputCount: request.referenceCandidates.filter(\.scopeMatch).count,
        detail: "out-of-scope action candidates retained only so the resolver can block them"),
      ContextPipelineTrace(
        stage: .evidenceRank, inputCount: request.referenceCandidates.count,
        outputCount: referenceGraph?.nodes.count ?? 0,
        detail: "scope, recency, authority, confidence, evidence, and salience ranked"),
      ContextPipelineTrace(
        stage: .ambiguityCheck, inputCount: referenceGraph?.nodes.count ?? 0,
        outputCount: referenceResolution == .none ? 0 : 1,
        detail: resolutionDescription(referenceResolution)),
    ]
    return ContextBuildMetadata(
      entities: entities, referenceGraph: referenceGraph,
      referenceResolution: referenceResolution, trace: trace)
  }

  private func resolveReference(
    parsed: ParsedContextUtterance,
    request: DeepContextRequest
  ) -> (ReferenceResolutionGraph?, ReferenceResolution) {
    guard let reference = parsed.implicitReference else { return (nil, .none) }
    let candidates = request.referenceCandidates.map {
      applyingIntentCapability($0, capability: request.intent.capability)
    }
    return (
      resolver.graph(
        reference: reference, candidates: candidates, referenceDate: request.referenceDate,
        explicitlyConfirmedTargetID: request.explicitlyConfirmedTargetID),
      resolver.resolve(
        reference: reference, candidates: candidates, referenceDate: request.referenceDate,
        explicitlyConfirmedTargetID: request.explicitlyConfirmedTargetID)
    )
  }

  private func finalizeBuild(
    _ preparation: ContextBuildPreparation,
    request: DeepContextRequest,
    actor: ActorID,
    correlationID: UUID,
    startedAt: Date
  ) async throws(AuraError) -> DeepContextResult {
    var exclusions = preparation.baseBundle.exclusions
    let filteredItems = preparation.allItems.filter { item in
      let excluded =
        !item.stage.isMandatory
        && request.inclusionOverride.excludedSourceIDs.contains(item.sourceID)
      if excluded {
        exclusions.append("excluded by per-turn user override: \(item.sourceID)")
      }
      return !excluded
    }
    let budgeted = try budget(
      items: filteredItems, forcedRecordIDs: request.inclusionOverride.includedMemoryRecordIDs,
      maxTokens: configuration.maxTokenBudget)
    let baseBundle = rebuiltBundle(
      preparation.baseBundle, budgeted: budgeted, filteredCount: filteredItems.count,
      graphCount: preparation.graphItemCount,
      exclusions: exclusions)
    var trace = preparation.trace
    trace.append(
      ContextPipelineTrace(
        stage: .finalBundle, inputCount: filteredItems.count, outputCount: baseBundle.items.count,
        detail: "\(budgeted.tokens)/\(configuration.maxTokenBudget) estimated tokens"))
    let elapsed = Date().timeIntervalSince(startedAt)
    let result = DeepContextResult(
      parsedUtterance: preparation.parsed, intent: request.intent,
      entities: preparation.entities, referenceGraph: preparation.referenceGraph,
      referenceResolution: preparation.referenceResolution,
      bundle: baseBundle,
      inspection: baseBundle.items.map {
        ContextInspectionItem(item: $0, estimatedTokens: Self.estimateTokens($0.summary))
      }, trace: trace, estimatedTokenCount: budgeted.tokens, elapsedSeconds: elapsed)
    await emit(
      DeepContextBuiltEvent(
        sessionID: request.sessionID, itemCount: baseBundle.items.count,
        estimatedTokenCount: budgeted.tokens, tokenBudget: configuration.maxTokenBudget,
        elapsedSeconds: elapsed, latencyBudgetSeconds: configuration.lookupLatencyBudgetSeconds,
        metLatencyBudget: elapsed <= configuration.lookupLatencyBudgetSeconds),
      actor: actor, correlationID: correlationID)
    return result
  }

  private func rebuiltBundle(
    _ original: ContextBundle,
    budgeted: ContextBudgetResult,
    filteredCount: Int,
    graphCount: Int,
    exclusions: [String]
  ) -> ContextBundle {
    ContextBundle(
      sessionID: original.sessionID, utterance: original.utterance, purpose: original.purpose,
      requestingComponent: original.requestingComponent, deliveryPolicy: original.deliveryPolicy,
      generatedAt: original.generatedAt,
      items: budgeted.items.sorted {
        $0.stage == $1.stage ? $0.score > $1.score : $0.stage < $1.stage
      }, consideredCandidateCount: original.consideredCandidateCount + graphCount,
      droppedCandidateCount: original.droppedCandidateCount
        + max(0, filteredCount - budgeted.items.count),
      tokenBudget: configuration.maxTokenBudget, estimatedTokenCount: budgeted.tokens,
      exclusions: exclusions, unresolvedContradictions: original.unresolvedContradictions)
  }
}
