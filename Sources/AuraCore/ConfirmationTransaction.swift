import Foundation

/// Truthful lifecycle for one side-effecting confirmation request.
public enum ConfirmationTransactionState: String, Codable, Sendable, Equatable, CaseIterable {
  case proposed
  case authorized
  case executing
  case executed
  case verifying
  case verified
  case completedWithWarning
  case failed
  case cancelled
  case unknown
}

public enum ConfirmationTransactionError: Error, Codable, Sendable, Equatable {
  case notFound
  case expired
  case invalidState(ConfirmationTransactionState)
  case invalidResponse
  case planChanged
  case contextMismatch
}

/// Immutable request identity plus mutable lifecycle state for one confirmation.
public struct ConfirmationTransaction: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let requestID: UUID
  public let planHash: String
  public let normalizedPlanHash: String?
  public let capabilityIdentifier: String
  public let targetSummary: String
  public let sideEffects: [String]
  public let nonce: String
  public let issuedAt: Date
  public let expiresAt: Date
  public let turnContext: TurnContext?
  public let state: ConfirmationTransactionState
  public let accepted: Bool?
  public let outcomeSummary: String?

  public init(
    id: UUID = UUID(),
    requestID: UUID,
    planHash: String,
    normalizedPlanHash: String? = nil,
    capabilityIdentifier: String,
    targetSummary: String,
    sideEffects: [String],
    nonce: String,
    issuedAt: Date,
    expiresAt: Date,
    turnContext: TurnContext?,
    state: ConfirmationTransactionState = .proposed,
    accepted: Bool? = nil,
    outcomeSummary: String? = nil
  ) {
    self.id = id
    self.requestID = requestID
    self.planHash = planHash
    self.normalizedPlanHash = normalizedPlanHash
    self.capabilityIdentifier = capabilityIdentifier
    self.targetSummary = targetSummary
    self.sideEffects = sideEffects
    self.nonce = nonce
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.turnContext = turnContext
    self.state = state
    self.accepted = accepted
    self.outcomeSummary = outcomeSummary
  }

  func changing(
    state: ConfirmationTransactionState,
    accepted: Bool? = nil,
    outcomeSummary: String? = nil
  ) -> ConfirmationTransaction {
    ConfirmationTransaction(
      id: id,
      requestID: requestID,
      planHash: planHash,
      normalizedPlanHash: normalizedPlanHash,
      capabilityIdentifier: capabilityIdentifier,
      targetSummary: targetSummary,
      sideEffects: sideEffects,
      nonce: nonce,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      turnContext: turnContext,
      state: state,
      accepted: accepted ?? self.accepted,
      outcomeSummary: outcomeSummary ?? self.outcomeSummary)
  }
}

/// In-memory, fail-closed transaction ledger. A new process starts with no
/// authorized transactions, so restart cannot replay a prior approval.
public actor ConfirmationTransactionStore {
  private var transactions: [UUID: ConfirmationTransaction] = [:]
  private let now: @Sendable () -> Date

  public init(now: @escaping @Sendable () -> Date = Date.init) {
    self.now = now
  }

  @discardableResult
  public func propose(
    challenge: PolicyConfirmationChallenge,
    sideEffects: [String] = []
  ) -> ConfirmationTransaction {
    let transaction = ConfirmationTransaction(
      id: challenge.transactionID ?? UUID(),
      requestID: challenge.requestID,
      planHash: challenge.expectedHash,
      normalizedPlanHash: challenge.planHash,
      capabilityIdentifier: challenge.requestedAction.identifier,
      targetSummary: challenge.targetSummary,
      sideEffects: sideEffects,
      nonce: challenge.nonce,
      issuedAt: challenge.issuedAt,
      expiresAt: challenge.expiresAt,
      turnContext: challenge.turnContext)
    transactions[transaction.requestID] = transaction
    return transaction
  }

  public func transaction(for requestID: UUID) -> ConfirmationTransaction? {
    transactions[requestID]
  }

  @discardableResult
  public func authorize(
    _ response: PolicyConfirmationResponse,
    planHash: String? = nil
  ) throws -> ConfirmationTransaction {
    guard let transaction = transactions[response.requestID] else {
      throw ConfirmationTransactionError.notFound
    }
    guard transaction.state == .proposed else {
      throw ConfirmationTransactionError.invalidState(transaction.state)
    }
    guard now() < transaction.expiresAt else {
      transactions[response.requestID] = transaction.changing(
        state: .cancelled, outcomeSummary: "expired")
      throw ConfirmationTransactionError.expired
    }
    guard response.nonce == transaction.nonce,
      response.responseHash == transaction.planHash
    else {
      transactions[response.requestID] = transaction.changing(
        state: .cancelled, accepted: response.accepted, outcomeSummary: "invalid response")
      throw ConfirmationTransactionError.invalidResponse
    }
    if let planHash, planHash != (transaction.normalizedPlanHash ?? transaction.planHash) {
      throw ConfirmationTransactionError.planChanged
    }
    guard response.accepted else {
      transactions[response.requestID] = transaction.changing(
        state: .cancelled, accepted: false, outcomeSummary: "user declined")
      throw ConfirmationTransactionError.invalidResponse
    }
    let authorized = transaction.changing(state: .authorized, accepted: true)
    transactions[response.requestID] = authorized
    return authorized
  }

  @discardableResult
  public func beginExecution(
    requestID: UUID,
    planHash: String,
    context: TurnContext
  ) throws -> ConfirmationTransaction {
    guard let transaction = transactions[requestID] else {
      throw ConfirmationTransactionError.notFound
    }
    guard transaction.state == .authorized else {
      throw ConfirmationTransactionError.invalidState(transaction.state)
    }
    guard transaction.turnContext?.sessionID == context.sessionID,
      transaction.turnContext?.correlationID == context.correlationID
    else {
      throw ConfirmationTransactionError.contextMismatch
    }
    guard planHash == (transaction.normalizedPlanHash ?? transaction.planHash) else {
      throw ConfirmationTransactionError.planChanged
    }
    let executing = transaction.changing(state: .executing)
    transactions[requestID] = executing
    return executing
  }

  @discardableResult
  public func beginLatestExecution(
    context: TurnContext,
    planHash: String? = nil
  ) throws -> ConfirmationTransaction {
    guard
      let requestID = transactions.values.first(where: { transaction in
        transaction.state == .authorized
          && transaction.turnContext?.sessionID == context.sessionID
          && transaction.turnContext?.correlationID == context.correlationID
      })?.requestID
    else {
      throw ConfirmationTransactionError.notFound
    }
    guard let transaction = transactions[requestID] else {
      throw ConfirmationTransactionError.notFound
    }
    return try beginExecution(
      requestID: requestID,
      planHash: planHash ?? transaction.normalizedPlanHash ?? transaction.planHash,
      context: context)
  }

  @discardableResult
  public func completeLatestExecution(
    context: TurnContext,
    verified: Bool,
    summary: String
  ) throws -> ConfirmationTransaction {
    guard
      let requestID = transactions.values.first(where: { transaction in
        transaction.state == .executing
          && transaction.turnContext?.sessionID == context.sessionID
          && transaction.turnContext?.correlationID == context.correlationID
      })?.requestID
    else {
      throw ConfirmationTransactionError.notFound
    }
    _ = try markExecuted(requestID: requestID, summary: summary)
    _ = try beginVerification(requestID: requestID)
    return try completeVerification(requestID: requestID, verified: verified, summary: summary)
  }

  public func markExecuted(requestID: UUID, summary: String) throws -> ConfirmationTransaction {
    try transition(requestID: requestID, from: .executing, to: .executed, summary: summary)
  }

  public func beginVerification(requestID: UUID) throws -> ConfirmationTransaction {
    try transition(requestID: requestID, from: .executed, to: .verifying)
  }

  public func completeVerification(
    requestID: UUID,
    verified: Bool,
    summary: String
  ) throws -> ConfirmationTransaction {
    guard let transaction = transactions[requestID] else {
      throw ConfirmationTransactionError.notFound
    }
    guard transaction.state == .verifying else {
      throw ConfirmationTransactionError.invalidState(transaction.state)
    }
    let finalState: ConfirmationTransactionState = verified ? .verified : .failed
    let completed = transaction.changing(state: finalState, outcomeSummary: summary)
    transactions[requestID] = completed
    return completed
  }

  public func finishVerified(requestID: UUID, summary: String) throws -> ConfirmationTransaction {
    guard let transaction = transactions[requestID] else {
      throw ConfirmationTransactionError.notFound
    }
    guard transaction.state == .verified else {
      throw ConfirmationTransactionError.invalidState(transaction.state)
    }
    let completed = transaction.changing(state: .verified, outcomeSummary: summary)
    transactions[requestID] = completed
    return completed
  }

  public func cancel(requestID: UUID, reason: String) throws -> ConfirmationTransaction {
    guard let transaction = transactions[requestID] else {
      throw ConfirmationTransactionError.notFound
    }
    guard transaction.state != .completedWithWarning, transaction.state != .failed else {
      throw ConfirmationTransactionError.invalidState(transaction.state)
    }
    let cancelled = transaction.changing(state: .cancelled, outcomeSummary: reason)
    transactions[requestID] = cancelled
    return cancelled
  }

  private func transition(
    requestID: UUID,
    from expectedState: ConfirmationTransactionState,
    to newState: ConfirmationTransactionState,
    summary: String? = nil
  ) throws -> ConfirmationTransaction {
    guard let transaction = transactions[requestID] else {
      throw ConfirmationTransactionError.notFound
    }
    guard transaction.state == expectedState else {
      throw ConfirmationTransactionError.invalidState(transaction.state)
    }
    let changed = transaction.changing(state: newState, outcomeSummary: summary)
    transactions[requestID] = changed
    return changed
  }
}
