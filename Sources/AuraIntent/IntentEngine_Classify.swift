import AuraContext
import AuraCore
import AuraMemory
import Foundation

private struct FinalizedClassification {
  let kind: IntentKind
  let category: IntentSemanticCategory
  let isAmbiguous: Bool
}

extension IntentEngine {
  /// Classify one completed conversational turn into a `TypedIntent`.
  /// Emits `IntentClassifiedEvent` unconditionally (including for `.unknown`
  /// results) — an ambiguous classification is itself audit-worthy.
  public func classify(
    _ turn: TurnCompletedEvent,
    correlationID: UUID,
    causationID: UUID
  ) async -> TypedIntent {
    let context = TurnContext(
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: causationID,
      activationSource: .text,
      actor: .user,
      authority: .userUtterance,
      sensitivity: .sensitive)
    return await classify(turn, context: context)
  }

  public func classify(
    _ turn: TurnCompletedEvent,
    context: TurnContext
  ) async -> TypedIntent {
    let raw = turn.text
    let normalized = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let result = await classifyResult(
      raw: raw, normalized: normalized, context: context)
    let classification = finalizedClassification(result)
    if classification.kind == .unknown, let proposedKind = result.proposedKind,
      let slotName = result.slots.first?.name
    {
      pendingClarification = PendingClarification(
        kind: proposedKind, slotName: slotName,
        expiresAt: now().addingTimeInterval(configuration.clarificationExpirySeconds))
    }
    let intent = TypedIntent(
      turnCorrelationID: context.correlationID, kind: classification.kind,
      semanticCategory: classification.category, rawUtterance: raw,
      normalizedUtterance: normalized,
      slots: result.slots, classificationConfidence: result.confidence,
      isAmbiguous: classification.isAmbiguous, language: result.language,
      dialogueAct: classification.isAmbiguous ? .clarify : result.dialogueAct,
      ambiguityReasons: result.ambiguityReasons, contextRequirements: result.contextRequirements,
      turnContext: context)
    let advancedContext = await emit(
      IntentClassifiedEvent(
        intentID: intent.id, turnCorrelationID: context.correlationID, kind: intent.kind.rawValue,
        semanticCategory: intent.semanticCategory, confidence: intent.classificationConfidence,
        isAmbiguous: intent.isAmbiguous, riskTier: intent.riskTier), context: context)
    let contextualIntent = intent.withTurnContext(advancedContext)
    recordReferenceCandidates(for: contextualIntent, context: advancedContext)
    let contextResult = await reconstructContext(for: contextualIntent, context: advancedContext)
    let resolvedIntent = applyResolvedReference(
      to: contextualIntent, contextResult: contextResult)
    let gatedIntent = applyReferenceResolutionGate(
      to: resolvedIntent, contextResult: contextResult)
    await persistIntentAsMemory(gatedIntent, context: advancedContext)
    return gatedIntent
  }

  private func classifyResult(
    raw: String, normalized: String, context: TurnContext
  ) async -> ClassificationResult {
    var result: ClassificationResult
    if let pendingClarification,
      now() < pendingClarification.expiresAt,
      let resolved = resolvePendingClarification(raw, pending: pendingClarification)
    {
      self.pendingClarification = nil
      result = resolved
    } else {
      if let pendingClarification, now() >= pendingClarification.expiresAt {
        self.pendingClarification = nil
      }
      result = classifier.classify(normalized: normalized, raw: raw)
    }
    return await applyStructuredNLUIfNeeded(
      result, raw: raw, context: context)
  }

  private func applyStructuredNLUIfNeeded(
    _ result: ClassificationResult, raw: String, context: TurnContext
  ) async -> ClassificationResult {
    guard result.kind == .converse, let structuredNLUBackend else { return result }
    do {
      let proposal = try await structuredNLUBackend.propose(
        prompt: makeStructuredNLUPrompt(utterance: raw, language: result.language),
        actor: .intent, sessionID: context.sessionID,
        correlationID: context.correlationID, causationID: context.causationID)
      if ProcessInfo.processInfo.environment["AURA_LOG_RESPONSE_TEXT"] == "1" {
        await logger.info(
          "TEXT_DEMO structuredNLU proposal: dialogueAct=\(proposal.dialogueAct) "
            + "confidence=\(proposal.confidence) language=\(proposal.language)",
          correlationID: context.correlationID, actor: .intent)
      }
      if let typed = structuredProposal(from: proposal),
        await isHallucinatedCapability(typed.capabilityID)
      {
        // R2: "Unknown capability IDs … must be rejected." Rejecting a
        // hallucination means discarding the proposal and keeping the
        // deterministic classification — not manufacturing ambiguity from it.
        // Downgrading here instead would turn a plain question into a
        // clarification round-trip purely because the model invented a name
        // (`RISK-SP-003-NLU-DOWNGRADE-VARIANCE`). The turn stays `.converse`,
        // which is not executable, so the safety invariant is untouched.
        if ProcessInfo.processInfo.environment["AURA_LOG_RESPONSE_TEXT"] == "1" {
          await logger.warning(
            "TEXT_DEMO structuredNLU proposed an unregistered capability; proposal rejected",
            correlationID: context.correlationID, actor: .intent)
        }
        return result
      }
      guard let structuredProposal = structuredProposal(from: proposal) else {
        if ProcessInfo.processInfo.environment["AURA_LOG_RESPONSE_TEXT"] == "1" {
          await logger.warning(
            "TEXT_DEMO structuredNLU proposal failed typed parsing",
            correlationID: context.correlationID, actor: .intent)
        }
        return result
      }
      return result.applying(structuredProposal)
    } catch {
      if ProcessInfo.processInfo.environment["AURA_LOG_RESPONSE_TEXT"] == "1" {
        await logger.warning(
          "TEXT_DEMO structuredNLU proposal failed: "
            + "errorType=\(String(describing: type(of: error)))",
          correlationID: context.correlationID, actor: .intent)
      }
      return result
    }
  }

  private func finalizedClassification(
    _ result: ClassificationResult
  ) -> FinalizedClassification {
    let isAmbiguous =
      result.confidence < configuration.minimumClassificationConfidence
      || result.kind == .unknown
    return FinalizedClassification(
      kind: isAmbiguous ? .unknown : result.kind,
      category: isAmbiguous ? .unknown : result.semanticCategory,
      isAmbiguous: isAmbiguous)
  }

  /// The most recent inspectable Phase 22 result for this session. It is
  /// turn-local runtime state, not a second persistence system.
  public func inspectLastContext() -> DeepContextResult? {
    lastContextResult
  }

  public func dialogueContextItems(maxItems: Int = 6) -> [DialogueContextItem] {
    guard let bundle = lastContextResult?.bundle else { return [] }
    var items = bundle.items
      .filter { $0.stage <= .activeAppOrWorkspace }
      .prefix(max(0, maxItems))
      .map {
        DialogueContextItem(
          sourceID: String(describing: $0.sourceID),
          summary: String($0.summary.prefix(240)),
          confidence: $0.confidence,
          authority: String(describing: $0.authority))
      }
    if items.count < max(0, maxItems),
      let result = lastContextResult,
      case .resolved(let candidate) = result.referenceResolution
    {
      items.append(
        DialogueContextItem(
          sourceID: String(describing: candidate.sourceID), summary: candidate.description,
          confidence: candidate.confidence, authority: String(describing: candidate.authority)))
    }
    return items
  }
}
