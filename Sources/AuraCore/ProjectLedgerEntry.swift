import Foundation

/// A serializable record of an append-only project ledger entry.
///
/// This is the programmatic representation of entries stored in
/// `ledger/PROJECT_LEDGER.md`. The store persists a copy so the runtime can
/// reconstruct recent context without parsing Markdown.
public struct ProjectLedgerEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let taskID: String
    public let title: String
    public let actor: String
    public let objective: String
    public let startingState: String
    public let evidenceInspected: [String]
    public let assumptions: [String]
    public let decisions: [String]
    public let filesChanged: [String]
    public let commandsExecuted: [String]
    public let testsAndResults: [String]
    public let securityPrivacyImpact: String
    public let unresolvedRisks: [String]
    public let rollback: String
    public let currentState: String
    public let nextSafeAction: String
    public let integrityHash: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        taskID: String,
        title: String,
        actor: String,
        objective: String,
        startingState: String,
        evidenceInspected: [String] = [],
        assumptions: [String] = [],
        decisions: [String] = [],
        filesChanged: [String] = [],
        commandsExecuted: [String] = [],
        testsAndResults: [String] = [],
        securityPrivacyImpact: String = "",
        unresolvedRisks: [String] = [],
        rollback: String = "",
        currentState: String = "",
        nextSafeAction: String = "",
        integrityHash: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskID = taskID
        self.title = title
        self.actor = actor
        self.objective = objective
        self.startingState = startingState
        self.evidenceInspected = evidenceInspected
        self.assumptions = assumptions
        self.decisions = decisions
        self.filesChanged = filesChanged
        self.commandsExecuted = commandsExecuted
        self.testsAndResults = testsAndResults
        self.securityPrivacyImpact = securityPrivacyImpact
        self.unresolvedRisks = unresolvedRisks
        self.rollback = rollback
        self.currentState = currentState
        self.nextSafeAction = nextSafeAction
        self.integrityHash = integrityHash
    }
}

/// Protocol for ledger backends. The runtime may use the SQLite store,
/// in-memory tests doubles, or both.
public protocol LedgerBackend: Sendable {
    func append(_ entry: ProjectLedgerEntry) async throws(AuraError)
    func entries(since: Date?, limit: Int) async throws(AuraError) -> [ProjectLedgerEntry]
}
