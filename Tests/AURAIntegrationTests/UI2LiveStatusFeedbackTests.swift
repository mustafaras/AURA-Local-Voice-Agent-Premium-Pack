import AuraCore
import Foundation
import Testing

@testable import AURA

/// UI-2 live status feedback unit pins, gate by gate.
struct UI2LiveStatusFeedbackTests {
  private static func envelope<P: EventPayload>(_ payload: P) -> EventEnvelope<P> {
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio, sensitivity: .internalLevel,
      payload: payload)
  }

  // MARK: - G2-2 Listening pulse

  @Test("listening pulse scales 0.9...1.15 with the real level, clamped")
  func listeningPulseScalesWithLevel() {
    #expect(AuraStatusPill.listeningPulseScale(status: .listening, inputLevel: 0) == 0.9)
    #expect(AuraStatusPill.listeningPulseScale(status: .listening, inputLevel: 1) == 1.15)
    #expect(AuraStatusPill.listeningPulseScale(status: .listening, inputLevel: 0.5) == 1.025)
    // Out-of-range inputs clamp rather than overshoot the documented range.
    #expect(AuraStatusPill.listeningPulseScale(status: .listening, inputLevel: -1) == 0.9)
    #expect(AuraStatusPill.listeningPulseScale(status: .listening, inputLevel: 2) == 1.15)
  }

  @Test("listening pulse is neutral outside the listening status or without a real level")
  func listeningPulseIsNeutralOtherwise() {
    // Honest-idle contract (same as AudioLevelBridge): nil level while
    // listening never fabricates a pulse.
    #expect(AuraStatusPill.listeningPulseScale(status: .listening, inputLevel: nil) == 1.0)
    // A stray level while not listening must never move the dot — the
    // pulse is status-gated, not level-gated alone.
    for status: AuraAppStatus in [.starting, .idle, .thinking, .speaking, .restricted, .stopped, .error]
    {
      #expect(AuraStatusPill.listeningPulseScale(status: status, inputLevel: 0.8) == 1.0)
    }
  }

  @Test("the listening pulse never drives an explicit animation — transform-only (11 §5)")
  func listeningPulseIsNeverAnimated() {
    // 11-motion-system.md §5: "Never animate on the inputLevel stream" —
    // grep-able in code, not only true by construction of the call site,
    // so a future edit that wires inputLevel into an `.animation(value:)`
    // fails this test rather than silently regressing frame cost.
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // Tests/AURAIntegrationTests/
      .deletingLastPathComponent() // Tests/
      .deletingLastPathComponent() // repo root
      .appendingPathComponent("Sources/AURA/AuraDesign.swift")
    let source = try? String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source != nil, "AuraDesign.swift must be readable from the test anchor")
    #expect(
      source?.contains("value: inputLevel") == false,
      "inputLevel must never be used as an .animation(value:) trigger")
    #expect(
      source?.contains(".scaleEffect(Self.listeningPulseScale") == true,
      "the listening pulse must be applied via a bare transform, not a state-driven animation")
  }

  // MARK: - G2-3 Speaking equalizer

  @Test("a real TTSStartedEvent sets isSpeakingResponse; every TTSStoppedEvent reason clears it")
  @MainActor
  func ttsEventsMapToSpeakingResponse() async throws {
    let model = AuraAppModel(startRuntime: false)
    let bus = AuraEventBus(logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "tts"))
    await model.subscribeToStatus(on: bus)
    #expect(!model.isSpeakingResponse, "must start false — honest idle, nil-safe for text-only mode")

    for reason: TTSStopReason in [.completed, .interrupted, .error, .timeout] {
      await bus.emit(
        Self.envelope(TTSStartedEvent(engineID: "test-engine", promptID: "p1", text: "hello")))
      #expect(model.isSpeakingResponse, "TTSStartedEvent must set the flag")
      await bus.emit(Self.envelope(TTSStoppedEvent(promptID: "p1", reason: reason)))
      #expect(!model.isSpeakingResponse, "stop reason \(reason) must clear the flag")
    }
  }

  @Test("no demo or mock path publishes a synthetic TTS event")
  func noSyntheticSpeakingSourceInDemoPaths() {
    // G2-3 hard boundary: isSpeakingResponse derives ONLY from the real TTS
    // lifecycle. `AuraAppModel_Runtime.swift` holds both the real
    // subscription (which only ever references `TTSStartedEvent.self` /
    // `TTSStoppedEvent.self` as subscribe-type tokens) and the one
    // demo/mock-adjacent path in this target, `runTextDemoIfRequested`
    // (AURA_TEXT_DEMO_SCRIPT) — that driver only submits text through the
    // real production pipeline and must never construct a TTS event itself.
    // A literal constructor call (`TTSStartedEvent(` / `TTSStoppedEvent(`,
    // with a paren) appearing anywhere in this file would mean something
    // other than the real `Conversation_TTS.swift` layer is fabricating one.
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // Tests/AURAIntegrationTests/
      .deletingLastPathComponent() // Tests/
      .deletingLastPathComponent() // repo root
      .appendingPathComponent("Sources/AURA/AuraAppModel_Runtime.swift")
    let source = try? String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source != nil, "AuraAppModel_Runtime.swift must be readable from the test anchor")
    #expect(
      source?.contains("TTSStartedEvent(") == false && source?.contains("TTSStoppedEvent(") == false,
      "AuraAppModel_Runtime.swift must only reference TTS events as .self subscribe tokens, never construct one"
    )
    // isSpeakingResponse must have exactly one writer: setSpeakingResponse.
    // More than one assignment site would mean a second, uncoordinated
    // source (e.g. a demo path) mutating it directly.
    let assignmentCount =
      (source ?? "").components(separatedBy: "isSpeakingResponse = isSpeaking").count - 1
    #expect(assignmentCount == 1, "isSpeakingResponse must have exactly one writer")
  }

  // MARK: - G2-4 Emergency badge

  @Test("the emergency badge appears via a single emergent pulse, never a looping animation")
  func emergencyBadgeUsesEmergentOneShotMotion() {
    // 11-motion-system.md §4: "badge appears instantly, one single pulse,
    // then static" — the only permitted pulse in the whole motion system,
    // and it must never become a loop (`repeatForever`/`.repeating`).
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // Tests/AURAIntegrationTests/
      .deletingLastPathComponent() // Tests/
      .deletingLastPathComponent() // repo root
    let badgeCallSites = [
      sourceURL.appendingPathComponent("Sources/AURA/AuraMenuView_Content.swift"),
      sourceURL.appendingPathComponent("Sources/AURA/AuraMenuBarPanel.swift"),
    ]
    for fileURL in badgeCallSites {
      let source = try? String(contentsOf: fileURL, encoding: .utf8)
      #expect(source != nil, "\(fileURL.lastPathComponent) must be readable from the test anchor")
      #expect(
        source?.contains("AuraEmergencyBadge(") == true,
        "\(fileURL.lastPathComponent) must render the shared emergency badge")
      #expect(
        source?.contains("Motion.emergent") == true,
        "\(fileURL.lastPathComponent)'s badge must use the emergent motion token")
      #expect(
        source?.contains("repeatForever") == false && source?.contains(".repeating(") == false,
        "\(fileURL.lastPathComponent) must never loop the emergency badge's animation")
    }
  }

  @Test("the emergency badge never carries meaning by colour alone")
  func emergencyBadgeCarriesSymbolAndText() {
    // F-005 discipline, extended to the badge: colour is never the sole
    // carrier. AuraEmergencyBadge must pair its colour with both a symbol
    // and real text (its `title` parameter), not colour alone.
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/AURA/AuraDesign.swift")
    let source = try? String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source != nil, "AuraDesign.swift must be readable from the test anchor")
    #expect(
      source?.contains("struct AuraEmergencyBadge") == true
        && source?.contains("hand.raised.fill") == true,
      "the emergency badge must exist and carry the hand.raised symbol alongside its text")
  }

  // MARK: - G2-5 Confirmation card entrance

  @Test("the confirmation card's conversation-tab entrance uses emergent motion, fast and sober")
  func confirmationCardEntranceUsesEmergentMotion() {
    // UI-2.prompt.md's G2-5 procedure: "confirmation card entrance uses
    // motion.emergent (fast, sober, no bounce)". The card's own `.transition`
    // must never overshoot past 1.0 scale (that would read as a bouncy pop,
    // not sober) and must never be a looping animation.
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/AURA/AuraMenuView_Content.swift")
    let source = try? String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source != nil, "AuraMenuView_Content.swift must be readable from the test anchor")
    #expect(
      source?.contains("AuraConfirmationCard(model: model, challenge: challenge)") == true,
      "the conversation tab must still render the confirmation card")
    #expect(
      source?.contains("Motion.emergent") == true,
      "the confirmation card's entrance must use the emergent motion token")
    #expect(
      source?.contains("repeatForever") == false && source?.contains(".repeating(") == false,
      "the confirmation card's entrance must never loop")
  }

  @Test("Deny remains first in both reading and tab order in the confirmation card")
  func confirmationCardKeepsDenyFirst() {
    // G2-5 explicitly requires this order PRESERVED, not re-verified from
    // scratch — this pins it so a future edit to AuraConfirmationCard cannot
    // silently reorder the safe choice behind the destructive one.
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/AURA/AuraMenuView.swift")
    let source = try? String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source != nil, "AuraMenuView.swift must be readable from the test anchor")
    let denyRange = source?.range(of: "confirmation.deny")
    let allowRange = source?.range(of: "confirmation.allowOnce")
    #expect(denyRange != nil && allowRange != nil, "both confirmation buttons must exist")
    if let denyRange, let allowRange {
      #expect(
        denyRange.lowerBound < allowRange.lowerBound,
        "Deny must appear before Allow in source order (reading and tab order)")
    }
  }
}
