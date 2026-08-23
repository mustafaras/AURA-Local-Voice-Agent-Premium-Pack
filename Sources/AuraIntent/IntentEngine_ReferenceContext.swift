import AuraContext
import AuraCore
import Foundation

/// Composition-root seam for live, typed context. The closure is intentionally
/// snapshot-shaped: `IntentEngine` never imports or reaches into task,
/// automation, VS Code, or backend implementations.
public typealias ReferenceContextProvider =
  @Sendable (TurnContext) async -> ReferenceContextSnapshot

extension IntentEngine {
  func recordReferenceCandidates(for intent: TypedIntent, context: TurnContext) {
    let observedAt = now()
    var additions: [ReferenceCandidate] = [
      ReferenceCandidate(
        sourceID: .dialogueTurn(turnID: context.turnID),
        description: "dialogue turn: \(intent.kind.rawValue)", authority: .userStated,
        confidence: intent.classificationConfidence, observedAt: observedAt,
        hasDirectEvidence: true, scopeMatch: true, entityKind: .conversationItem,
        conversationalSalience: 0.8),
      ReferenceCandidate(
        sourceID: .recentTool(toolID: intent.semanticCategory.rawValue),
        description: "tool: \(intent.semanticCategory.rawValue)", authority: .systemDerived,
        confidence: intent.classificationConfidence, observedAt: observedAt,
        hasDirectEvidence: true, scopeMatch: true, conversationalSalience: 0.55),
    ]

    for slot in intent.slots {
      switch slot.name {
      case IntentSlotName.filePath:
        additions.append(
          fileCandidate(
            path: slot.value, kind: .file, observedAt: observedAt,
            confidence: intent.classificationConfidence))
      case IntentSlotName.folderPath:
        additions.append(
          fileCandidate(
            path: slot.value, kind: .repository, observedAt: observedAt,
            confidence: intent.classificationConfidence))
      case IntentSlotName.bundleIdentifier:
        if let identifier = boundedIdentifier(slot.value) {
          additions.append(
            ReferenceCandidate(
              sourceID: .recentApplication(bundleIdentifier: identifier),
              description: "application: \(identifier)", authority: .userStated,
              confidence: intent.classificationConfidence, observedAt: observedAt,
              hasDirectEvidence: true, scopeMatch: true, entityKind: .application,
              conversationalSalience: 0.95))
        }
      case IntentSlotName.backend:
        if let identifier = boundedIdentifier(slot.value) {
          additions.append(
            backendCandidate(
              identifier: identifier, observedAt: observedAt,
              confidence: intent.classificationConfidence))
        }
      default:
        continue
      }
    }
    recentReferenceCandidates.append(contentsOf: additions)
    let retentionLimit = max(32, referenceAssembler.configuration.maxReferenceCandidates * 3)
    if recentReferenceCandidates.count > retentionLimit {
      recentReferenceCandidates.removeFirst(recentReferenceCandidates.count - retentionLimit)
    }
  }

  func assembledReferenceContext(for intent: TypedIntent, context: TurnContext) async
    -> (snapshot: ReferenceContextSnapshot, candidates: [ReferenceCandidate])
  {
    let snapshot = await referenceContextProvider?(context) ?? .empty
    let candidates = referenceAssembler.assemble(
      candidates: recentReferenceCandidates,
      activeWorkspace: snapshot.activeWorkspace,
      durableTasks: snapshot.durableTasks,
      backendIDs: context.backendIDs,
      referenceDate: now())
    return (snapshot, candidates)
  }

  private func fileCandidate(
    path: String,
    kind: ReferenceEntityKind,
    observedAt: Date,
    confidence: Double
  ) -> ReferenceCandidate {
    ReferenceCandidate(
      sourceID: .recentFile(path: path), description: "file: \(path)", authority: .userStated,
      confidence: confidence, observedAt: observedAt, hasDirectEvidence: true, scopeMatch: true,
      entityKind: kind, conversationalSalience: 1)
  }

  private func backendCandidate(
    identifier: String,
    observedAt: Date,
    confidence: Double
  ) -> ReferenceCandidate {
    ReferenceCandidate(
      sourceID: .backendIdentity(identifier: identifier), description: "backend: \(identifier)",
      authority: .userStated, confidence: confidence, observedAt: observedAt,
      hasDirectEvidence: true, scopeMatch: true, entityKind: .backend,
      conversationalSalience: 1)
  }

  private func boundedIdentifier(_ value: String) -> String? {
    let scalars = value.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F }
    let bounded = String(scalars.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !bounded.isEmpty,
      bounded.allSatisfy({ $0.isLetter || $0.isNumber || ".-_:/.".contains($0) })
    else { return nil }
    return bounded
  }
}
