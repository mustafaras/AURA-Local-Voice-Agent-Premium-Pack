import AuraCore
import Foundation
import Testing

struct ConfirmationTransactionTests {
  @Test func authorizedTransactionExecutesAndVerifiesExactlyOnce() async throws {
    let now = Date(timeIntervalSince1970: 100)
    let sessionID = UUID()
    let context = TurnContext(
      sessionID: sessionID,
      activationSource: .text,
      actor: .user,
      authority: .userUtterance,
      sensitivity: .sensitive)
    let requestID = UUID()
    let challenge = PolicyConfirmationChallenge(
      requestID: requestID,
      sessionID: sessionID,
      nonce: "nonce",
      issuedAt: now,
      requestedAction: .appTerminate,
      targetSummary: "Safari",
      riskTier: .mutation,
      expiresAt: now.addingTimeInterval(60),
      expectedHash: "plan-hash",
      turnContext: context)
    let store = ConfirmationTransactionStore(now: { now })
    let proposed = await store.propose(challenge: challenge, sideEffects: ["quit application"])
    #expect(proposed.state == .proposed)

    let response = PolicyConfirmationResponse(
      requestID: requestID,
      nonce: "nonce",
      responseHash: "plan-hash",
      accepted: true)
    let authorized = try await store.authorize(response)
    #expect(authorized.state == .authorized)
    let executing = try await store.beginExecution(
      requestID: requestID, planHash: "plan-hash", context: context)
    #expect(executing.state == .executing)
    do {
      _ = try await store.beginExecution(
        requestID: requestID, planHash: "plan-hash", context: context)
      Issue.record("replay execution unexpectedly succeeded")
    } catch let error as ConfirmationTransactionError {
      #expect(error == .invalidState(.executing))
    }
    _ = try await store.markExecuted(requestID: requestID, summary: "quit requested")
    _ = try await store.beginVerification(requestID: requestID)
    let verified = try await store.completeVerification(
      requestID: requestID, verified: true, summary: "application no longer running")
    #expect(verified.state == .verified)
  }

  @Test func expiryPlanChangeAndReplayFailClosed() async throws {
    let issued = Date(timeIntervalSince1970: 10)
    let expiredNow = Date(timeIntervalSince1970: 20)
    let context = TurnContext(
      sessionID: UUID(),
      activationSource: .pushToTalk,
      actor: .user,
      authority: .userUtterance,
      sensitivity: .sensitive)
    let challenge = PolicyConfirmationChallenge(
      requestID: UUID(),
      sessionID: context.sessionID,
      nonce: "nonce",
      issuedAt: issued,
      requestedAction: .shellExec,
      targetSummary: "echo",
      riskTier: .mutation,
      expiresAt: issued.addingTimeInterval(1),
      expectedHash: "original-plan",
      turnContext: context)
    let store = ConfirmationTransactionStore(now: { expiredNow })
    _ = await store.propose(challenge: challenge)
    let response = PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: "nonce",
      responseHash: "original-plan",
      accepted: true)
    do {
      _ = try await store.authorize(response)
      Issue.record("expired confirmation unexpectedly authorized")
    } catch let error as ConfirmationTransactionError {
      #expect(error == .expired)
    }

    let freshStore = ConfirmationTransactionStore(now: { issued })
    _ = await freshStore.propose(challenge: challenge)
    do {
      _ = try await freshStore.authorize(response, planHash: "changed-plan")
      Issue.record("changed plan unexpectedly authorized")
    } catch let error as ConfirmationTransactionError {
      #expect(error == .planChanged)
    }
    do {
      _ = try await freshStore.authorize(
        PolicyConfirmationResponse(
          requestID: challenge.requestID,
          nonce: "nonce",
          responseHash: "original-plan",
          accepted: false))
      Issue.record("declined confirmation unexpectedly authorized")
    } catch let error as ConfirmationTransactionError {
      #expect(error == .invalidResponse)
    }
  }

  @Test func newStoreCannotReplayPriorAuthorization() async throws {
    let challenge = PolicyConfirmationChallenge(
      requestID: UUID(),
      sessionID: UUID(),
      nonce: "nonce",
      issuedAt: Date(timeIntervalSince1970: 10),
      requestedAction: .appTerminate,
      targetSummary: "Mail",
      riskTier: .mutation,
      expiresAt: Date(timeIntervalSince1970: 100),
      expectedHash: "hash")
    let firstStore = ConfirmationTransactionStore(now: { Date(timeIntervalSince1970: 20) })
    _ = await firstStore.propose(challenge: challenge)
    let response = PolicyConfirmationResponse(
      requestID: challenge.requestID,
      nonce: "nonce",
      responseHash: "hash",
      accepted: true)
    _ = try await firstStore.authorize(response)

    let restartedStore = ConfirmationTransactionStore(now: { Date(timeIntervalSince1970: 20) })
    do {
      _ = try await restartedStore.authorize(response)
      Issue.record("restarted store replay unexpectedly authorized")
    } catch let error as ConfirmationTransactionError {
      #expect(error == .notFound)
    }
  }
}
