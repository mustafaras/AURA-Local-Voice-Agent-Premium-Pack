import AuraCore
import AuraPolicy
import Foundation

/// SP-010: the four read-first productivity handlers.
///
/// They follow the same sequence every other routed capability uses —
/// `resolvePolicy` → `ToolInvokedEvent` → adapter → `ToolResultEvent` — so
/// reads are audited exactly like actions. Three things are specific to this
/// group and deliberate:
///
/// * **A missing reader is not "no results."** When the composition root
///   wired no reader, the handler fails closed with a truthful reason instead
///   of answering as though the mailbox were empty. A fabricated empty answer
///   is worse than a refusal, because the user cannot tell it from the truth.
/// * **The policy target names the integration, not the content.** A mail
///   search target carries the provider host and never the query text or the
///   address, so `PolicyTarget` summaries in audit records stay free of
///   private data.
/// * **Ambiguity is a question, not a guess.** Two approved accounts and no
///   stated one produces `.ambiguous`, so the conversation asks which account
///   rather than picking whichever the adapter happened to sort first.
extension ToolRouter {
  func handleBrowserRead(
    _ intent: TypedIntent,
    contract: CapabilityManifest,
    executionContext: ToolExecutionContext
  ) async -> IntentExecutionOutcome {
    let profileID = intent.slotValue(IntentSlotName.profileID)
    return await runProductivityRead(
      intent, contract: contract, executionContext: executionContext,
      target: PolicyTarget(appID: "com.apple.Safari")
    ) { reader in
      await reader.readActiveBrowserTab(profileID: profileID)
    }
  }

  func handleMailRead(
    _ intent: TypedIntent,
    contract: CapabilityManifest,
    executionContext: ToolExecutionContext
  ) async -> IntentExecutionOutcome {
    guard let query = intent.slotValue(IntentSlotName.query), !query.isEmpty else {
      return .failed(reason: "missing \(IntentSlotName.query) slot")
    }
    let accountID = intent.slotValue(IntentSlotName.accountID)
    return await runProductivityRead(
      intent, contract: contract, executionContext: executionContext,
      // The provider host is the only target detail a policy rule can
      // usefully scope on. The query and the address stay out of the audit
      // target entirely.
      target: PolicyTarget(networkHost: contract.requiredNetworkDomains.first)
    ) { reader in
      if intent.slotValue(IntentSlotName.threadSummary) == "true" {
        await reader.summarizeMailThread(accountID: accountID, query: query)
      } else {
        await reader.searchMail(accountID: accountID, query: query, limit: 10)
      }
    }
  }

  func handleCalendarRead(
    _ intent: TypedIntent,
    contract: CapabilityManifest,
    executionContext: ToolExecutionContext
  ) async -> IntentExecutionOutcome {
    let dayRange = Int(intent.slotValue(IntentSlotName.dayRange) ?? "1") ?? 1
    let wantsFreeWindows = intent.slotValue(IntentSlotName.freeWindows) == "true"
    let minimumMinutes = Int(intent.slotValue(IntentSlotName.minimumMinutes) ?? "30") ?? 30
    return await runProductivityRead(
      intent, contract: contract, executionContext: executionContext, target: .empty
    ) { reader in
      if wantsFreeWindows {
        await reader.readCalendarFreeWindows(
          dayRange: dayRange, minimumMinutes: minimumMinutes)
      } else {
        await reader.readCalendarAgenda(dayRange: dayRange)
      }
    }
  }

  func handleContactsLookup(
    _ intent: TypedIntent,
    contract: CapabilityManifest,
    executionContext: ToolExecutionContext
  ) async -> IntentExecutionOutcome {
    guard let query = intent.slotValue(IntentSlotName.query), !query.isEmpty else {
      return .failed(reason: "missing \(IntentSlotName.query) slot")
    }
    return await runProductivityRead(
      intent, contract: contract, executionContext: executionContext, target: .empty
    ) { reader in
      await reader.lookupContacts(query: query, limit: 5)
    }
  }

  /// The shared body: policy first, then the read, then a result event whose
  /// summary was already redacted at the composition boundary.
  private func runProductivityRead(
    _ intent: TypedIntent,
    contract: CapabilityManifest,
    executionContext: ToolExecutionContext,
    target: PolicyTarget,
    read:
      @Sendable (any ProductivityReading) async -> Result<
        ProductivityReadResult, ProductivityReadFailure
      >
  ) async -> IntentExecutionOutcome {
    let policyResult = await resolvePolicy(
      intent, capability: contract.requiredCapability, target: target,
      executionContext: executionContext)
    switch policyResult {
    case .blocked(let outcome): return outcome
    case .allowed: break
    }

    guard let productivityReader else {
      // Registry availability should already have stopped this. Reaching here
      // means availability and wiring disagree, which is exactly the state
      // that must never be answered optimistically.
      let reason = "\(contract.id) has no wired integration in this build"
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "noProductivityReader:\(contract.id)"),
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
      return .blockedByPolicy(reason: reason)
    }

    await emit(
      ToolInvokedEvent(intentID: intent.id, toolID: contract.id),
      correlationID: executionContext.correlationID,
      causationID: executionContext.causationID)

    switch await read(productivityReader) {
    case .success(let result):
      let summary =
        result.isDegraded
        ? "\(result.summary) (reported from a degraded integration state)"
        : result.summary
      await emit(
        ToolResultEvent(
          intentID: intent.id, toolID: contract.id, succeeded: true,
          summary: "\(summary) [source \(result.sourceFingerprint)]"),
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
      return .executed(summary: summary, hasSpokenResponse: true)
    case .failure(let failure):
      return await productivityFailureOutcome(
        failure, intent: intent, contract: contract, executionContext: executionContext)
    }
  }

  private func productivityFailureOutcome(
    _ failure: ProductivityReadFailure,
    intent: TypedIntent,
    contract: CapabilityManifest,
    executionContext: ToolExecutionContext
  ) async -> IntentExecutionOutcome {
    let summary: String
    let outcome: IntentExecutionOutcome
    switch failure {
    case .ambiguous(let question):
      // An ambiguous account is not a failure of the integration, so it is
      // not recorded as one: the turn ends by asking the user to choose.
      await emit(
        IntentBlockedEvent(intentID: intent.id, reason: "accountAmbiguous:\(contract.id)"),
        correlationID: executionContext.correlationID,
        causationID: executionContext.causationID)
      return .ambiguous(clarifyingQuestion: question)
    case .notConfigured(let reason):
      summary = "\(contract.id) is not connected: \(reason)"
      outcome = .blockedByPolicy(reason: summary)
    case .unavailable(let reason):
      summary = "\(contract.id) is unavailable: \(reason)"
      outcome = .blockedByPolicy(reason: summary)
    case .failed(let reason):
      summary = "\(contract.id) failed: \(reason)"
      outcome = .failed(reason: summary)
    }
    await emit(
      ToolResultEvent(
        intentID: intent.id, toolID: contract.id, succeeded: false, summary: summary),
      correlationID: executionContext.correlationID,
      causationID: executionContext.causationID)
    return outcome
  }
}
