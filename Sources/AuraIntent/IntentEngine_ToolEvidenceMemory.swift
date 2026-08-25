import AuraContext
import AuraCore
import AuraMemory
import Foundation

extension IntentEngine {
  /// Persist a verified tool observation as a `projectFact` memory record.
  ///
  /// This is the production counterpart to `persistIntentAsMemory`. That one
  /// records *what the user asked*; this one records *what a tool actually
  /// observed*, which is the only kind of write allowed to claim
  /// `MemoryProvenance.observed` and the `.verifiedToolEvidence` write source.
  ///
  /// Two properties matter and are deliberate:
  ///
  /// - **Stable subject.** The subject is the observation's `factKey`, not a
  ///   per-turn identifier. Running the same command again is an observation
  ///   of the same fact, so a changed answer collides on
  ///   `(memoryClass, subject, scope)` and `ContradictionDetector` raises a
  ///   `MemoryConflict` the user resolves in the Privacy tab. A unique
  ///   subject would make contradiction detection structurally unreachable.
  /// - **Global scope.** A project fact is not session-local: it must survive
  ///   restart, and a contradiction between yesterday's answer and today's is
  ///   precisely what the user needs to see.
  ///
  /// Memory persistence stays best-effort, exactly as it is for classifier
  /// memory: a rejected write (for example, output that trips the engine's
  /// secret screen) is emitted as an event and never blocks the turn.
  func persistToolObservationAsProjectFact(
    _ observation: ToolObservation,
    context: TurnContext
  ) async {
    guard let memoryEngine else { return }

    let draft = MemoryRecordDraft(
      memoryClass: .projectFact,
      subject: observation.factKey,
      statement: observation.statement,
      evidenceReferences: observation.evidenceReferences,
      provenance: .observed(source: observation.sourceActor),
      confidence: 1.0,
      sensitivity: .internalLevel,
      observedAt: observation.observedAt,
      retention: .indefinite,
      purpose: "verified project fact derived from tool evidence",
      scope: .global
    )

    do {
      let outcome = try await memoryEngine.append(
        MemoryWriteRequest(
          draft: draft, source: .verifiedToolEvidence(actor: observation.sourceActor)),
        actor: .intent, sessionID: context.sessionID, correlationID: context.correlationID)

      let record: MemoryRecord
      let conflicted: Bool
      switch outcome {
      case .recorded(let recorded):
        record = recorded
        conflicted = false
      case .recordedWithConflict(let recorded, _):
        record = recorded
        conflicted = true
      }

      _ = try? await memoryEngine.annotate(
        recordID: record.id,
        nodeKind: .fact,
        label: conflicted
          ? "\(observation.toolID) observation contradicts the retained fact for "
            + "\(observation.factKey)"
          : "\(observation.toolID) observation recorded for \(observation.factKey)",
        authority: .derivedTool,
        confidence: 1.0,
        actor: .intent,
        correlationID: context.correlationID
      )
    } catch {
      _ = await emit(
        IntentMemoryFailedEvent(
          intentID: UUID(),
          turnCorrelationID: context.correlationID,
          reason: String(describing: error)
        ),
        context: context)
    }
  }
}
