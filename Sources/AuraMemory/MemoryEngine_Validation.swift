import AuraCore
import AuraStore
import Foundation

extension MemoryEngine {
  // MARK: - Validation

  func validateWritePolicy(_ request: MemoryWriteRequest) throws(AuraError) {
    let draft = request.draft
    guard !draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.memoryError("memory subject must not be empty")
    }
    guard !draft.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.memoryError("memory purpose must not be empty")
    }
    guard !containsSecretLikeText("\(draft.subject) \(draft.statement)") else {
      throw AuraError.memoryError("secret-like content cannot be persisted in memory")
    }

    try validateSourcePolicy(request)
  }

  private func validateSourcePolicy(_ request: MemoryWriteRequest) throws(AuraError) {
    switch request.source {
    case .rawContent, .modelOutput, .untrustedExternalContent:
      try rejectUntrustedSource()
    case .explicitUser:
      try validateExplicitUserSource(request.draft)
    case .verifiedToolEvidence:
      try validateVerifiedToolSource(request.draft)
    case .activeDurableTask:
      try validateDurableTaskSource(request.draft)
    case .approvedSummary:
      try validateApprovedSummarySource(request.draft)
    case .classifierDerived:
      try validateClassifierSource(request.draft)
    case .inferred:
      // Inference may be retained only as explicitly labeled, non-authoritative
      // memory. `MemoryProvenance.inferred` prevents it from masquerading as a
      // user or tool fact in ranking and reference resolution.
      break
    }
  }

  private func rejectUntrustedSource() throws(AuraError) {
    throw AuraError.memoryError(
      "raw, untrusted, and model-generated content requires an explicit user-approved summary")
  }

  private func validateExplicitUserSource(_ draft: MemoryRecordDraft) throws(AuraError) {
    guard draft.memoryClass != .auditSecurity else {
      throw AuraError.memoryError("users cannot author audit/security memory")
    }
  }

  private func validateVerifiedToolSource(_ draft: MemoryRecordDraft) throws(AuraError) {
    guard !draft.evidenceReferences.isEmpty else {
      throw AuraError.memoryError("verified tool memory requires evidence references")
    }
  }

  private func validateDurableTaskSource(_ draft: MemoryRecordDraft) throws(AuraError) {
    guard draft.memoryClass == .taskState, draft.scope.taskID != nil else {
      throw AuraError.memoryError("durable task memory requires a task scope")
    }
  }

  private func validateApprovedSummarySource(_ draft: MemoryRecordDraft) throws(AuraError) {
    guard draft.memoryClass == .sessionSummary, !draft.evidenceReferences.isEmpty else {
      throw AuraError.memoryError("session summaries require approval and source evidence")
    }
  }

  private func validateClassifierSource(_ draft: MemoryRecordDraft) throws(AuraError) {
    guard draft.memoryClass == .workingConversation else {
      throw AuraError.memoryError("classifier-derived memory is limited to working conversation")
    }
    guard draft.statement.utf8.count <= 512 else {
      throw AuraError.memoryError("classifier-derived memory exceeds the bounded summary size")
    }
    switch draft.retention {
    case .ephemeral, .sessionScoped:
      break
    case .indefinite, .auditRetention:
      throw AuraError.memoryError("classifier-derived memory cannot use durable retention")
    }
  }

  func containsSecretLikeText(_ text: String) -> Bool {
    let normalized = text.lowercased()
    if let range = normalized.range(of: "sk-") {
      let suffix = normalized[range.upperBound...]
      if suffix.prefix(20).count == 20 { return true }
    }
    if let range = normalized.range(of: "akia") {
      let suffix = normalized[range.upperBound...]
      if suffix.prefix(16).count == 16 { return true }
    }
    if normalized.contains("private key") {
      return true
    }
    if normalized.contains("-----begin") && normalized.contains("private key-----") {
      return true
    }
    let patterns = [
      #"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"#,
      #"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#,
    ]
    return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
  }

  /// "Facts require evidence. Inference is labeled." — any non-inferred
  /// provenance must cite at least one evidence reference; `.inferred`
  /// itself is the label, so it may have none.
  func validateEvidence(_ draft: MemoryRecordDraft) throws(AuraError) {
    if case .inferred = draft.provenance { return }
    guard !draft.evidenceReferences.isEmpty else {
      throw AuraError.memoryError(
        "facts require at least one evidence reference (provenance was not .inferred)")
    }
  }

  /// "Sensitive personal facts are not retained without explicit purpose and
  /// consent" — mechanically enforced for the transient memory classes:
  /// `.secret`-sensitivity ephemeral/working/session-summary records must
  /// not use indefinite or audit retention.
  func validateSensitiveRetention(_ draft: MemoryRecordDraft) throws(AuraError) {
    guard draft.sensitivity == .secret else { return }
    let transientClasses: Set<MemoryClass> = [
      .ephemeralAudio, .workingConversation, .sessionSummary,
    ]
    guard transientClasses.contains(draft.memoryClass) else { return }
    switch draft.retention {
    case .indefinite, .auditRetention:
      throw AuraError.memoryError(
        "secret-sensitivity \(draft.memoryClass) records must use ephemeral or "
          + "session-scoped retention, not \(draft.retention)"
      )
    case .ephemeral, .sessionScoped:
      break
    }
  }

  func projectionKey(for record: MemoryRecord) -> String {
    [
      record.memoryClass.rawValue,
      record.subject,
      record.scope.projectID ?? "",
      record.scope.taskID?.uuidString ?? "",
      record.scope.sessionID?.uuidString ?? "",
    ].joined(separator: "\u{1F}")
  }

  func nodeKind(for memoryClass: MemoryClass) -> ProvenanceNodeKind {
    switch memoryClass {
    case .userPreference: return .preference
    case .taskState: return .task
    case .proceduralKnowledge: return .decision
    case .sessionSummary, .workingConversation: return .utterance
    case .ephemeralAudio: return .file
    case .projectFact: return .fact
    case .auditSecurity: return .fact
    }
  }

  func authority(for provenance: MemoryProvenance) -> ProvenanceAuthority {
    switch provenance {
    case .userStated: return .userStated
    case .observed(let source), .systemDerived(let source):
      switch source {
      case .policy: return .derivedPolicy
      case .user: return .userConfirmed
      case .lifecycle: return .derivedTool
      case .system, .audio, .screen, .automation, .memory,
        .agentCodex, .agentClaude, .agentCopilot, .agentOllama,
        .orchestrator, .task, .context, .computerUse, .security,
        .plugin, .intent, .unknown:
        return .derivedTool
      }
    case .inferred: return .inferred
    }
  }

  func emit<Payload: EventPayload>(
    _ payload: Payload,
    actor: ActorID,
    correlationID: UUID,
    causationID: UUID
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID,
      causationID: causationID,
      actor: actor,
      sensitivity: .internalLevel,
      payload: payload
    )
    await eventBus.emit(envelope)
  }
}
