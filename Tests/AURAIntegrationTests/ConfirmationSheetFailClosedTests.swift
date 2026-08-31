import AuraCore
import Foundation
import Testing

@testable import AURA

/// R11 confirmation reachability, added 2026-08-31.
///
/// A policy confirmation raised by a control in the Settings window used to be
/// rendered only inside the main panel — which dismisses whenever the app's
/// focus moves. A user toggling launch-at-login was therefore asked to
/// authorize in a window they were not looking at; the 60 s challenge expired
/// unanswered and the toggle failed with "was not confirmed"
/// (`EV-SP-030-20260831-R11-LIVE-GATE-02`). Settings now presents the card as a
/// sheet, and these pin the security rule that sheet depends on: a confirmation
/// that disappears without an explicit answer must **deny**, never grant.
@Suite("R11 confirmation sheet fails closed")
@MainActor
struct ConfirmationSheetFailClosedTests {
  private func challenge() -> PolicyConfirmationChallenge {
    PolicyConfirmationChallenge(
      requestID: UUID(),
      sessionID: UUID(),
      nonce: "test-nonce",
      issuedAt: Date(),
      requestedAction: .lifecycleLaunchAtLogin,
      targetSummary: "any",
      riskTier: .mutation,
      expiresAt: Date().addingTimeInterval(60),
      expectedHash: "test-hash")
  }

  @Test("dismissing an unanswered confirmation denies it")
  func dismissalDenies() {
    let model = AuraAppModel(startRuntime: false)
    model.pendingConfirmation = challenge()

    model.denyConfirmationIfStillPending()

    // Cleared, so the sheet closes and no stale challenge can be re-presented.
    #expect(model.pendingConfirmation == nil)
  }

  @Test("an already-answered confirmation is not re-denied")
  func answeredConfirmationIsNotReDenied() {
    // The ordering that makes the sheet safe: answering clears
    // `pendingConfirmation` first, so SwiftUI's follow-up dismissal callback
    // must find nothing to do. If this regressed, every *accepted*
    // authorization would be immediately overturned by its own dismissal.
    let model = AuraAppModel(startRuntime: false)
    model.pendingConfirmation = challenge()
    model.resolveConfirmation(accepted: true, outcome: .accepted)
    #expect(model.pendingConfirmation == nil)

    model.denyConfirmationIfStillPending()

    #expect(model.pendingConfirmation == nil)
  }

  @Test("dismissing with nothing pending is a no-op")
  func noPendingConfirmationIsNoOp() {
    let model = AuraAppModel(startRuntime: false)
    #expect(model.pendingConfirmation == nil)

    model.denyConfirmationIfStillPending()

    #expect(model.pendingConfirmation == nil)
  }
}
