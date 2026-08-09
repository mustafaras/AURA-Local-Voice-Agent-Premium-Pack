import Foundation

// MARK: - Retrieval stage

/// The fixed retrieval sequence from `docs/subsystems/22_CONTEXT_RECONSTRUCTION.md`:
/// current utterance → conversation state → pending confirmation/task →
/// active app/workspace → project ledger → recent decisions → preferences →
/// semantic retrieval.
///
/// Stages `.currentUtterance` through `.activeAppOrWorkspace` are always
/// included verbatim (never ranked away); later stages are candidates that
/// compete for a bounded budget via `ContextRanking`.
public enum ContextRetrievalStage: Int, Codable, Sendable, Equatable, CaseIterable, Comparable {
  case currentUtterance = 0
  case conversationState = 1
  case pendingConfirmationOrTask = 2
  case activeAppOrWorkspace = 3
  case projectLedger = 4
  case recentDecisions = 5
  case preferences = 6
  case semanticRetrieval = 7

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

  /// Stages that are always included in a bundle, never subject to the
  /// ranked/truncated budget.
  public var isMandatory: Bool { rawValue <= ContextRetrievalStage.activeAppOrWorkspace.rawValue }
}

// MARK: - Authority

/// Ranked authority of a piece of context, used as one ranking dimension.
/// Ordered least to most authoritative.
public enum ContextAuthority: Int, Codable, Sendable, Equatable, CaseIterable, Comparable {
  case inferred = 0
  case observed = 1
  case systemDerived = 2
  case userStated = 3

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

  /// Map a `MemoryProvenance` onto its ranked authority tier.
  public static func from(_ provenance: MemoryProvenance) -> ContextAuthority {
    switch provenance {
    case .userStated: return .userStated
    case .systemDerived: return .systemDerived
    case .observed: return .observed
    case .inferred: return .inferred
    }
  }
}

// MARK: - Source ID

/// Identifies exactly where one item in a context bundle came from, so every
/// bundle is traceable back to its origin — "source IDs included in every
/// context bundle."
public enum ContextSourceID: Codable, Sendable, Equatable, Hashable {
  case utterance
  case conversationState
  case pendingConfirmation(requestID: UUID)
  case pendingTask(taskID: UUID)
  case activeWorkspace
  case projectLedgerEntry(entryID: UUID)
  case decision(entryID: UUID, index: Int)
  case memoryRecord(recordID: UUID)
  case provenanceNode(nodeID: UUID)
}

// MARK: - Active workspace snapshot

/// A minimal, source-agnostic snapshot of "what the user is currently
/// looking at" — the frontmost application and/or an editor workspace.
/// Callers (automation, VS Code bridge) build this from whichever live
/// source they have; `ContextEngine` does not reach into those subsystems
/// itself, keeping this module's dependency surface small.
public struct ActiveWorkspaceSnapshot: Codable, Sendable, Equatable {
  public let appBundleIdentifier: String?
  public let appDisplayName: String?
  public let workspaceFolderPaths: [String]
  public let activeFilePath: String?
  public let capturedAt: Date

  public init(
    appBundleIdentifier: String? = nil,
    appDisplayName: String? = nil,
    workspaceFolderPaths: [String] = [],
    activeFilePath: String? = nil,
    capturedAt: Date = Date()
  ) {
    self.appBundleIdentifier = appBundleIdentifier
    self.appDisplayName = appDisplayName
    self.workspaceFolderPaths = workspaceFolderPaths
    self.activeFilePath = activeFilePath
    self.capturedAt = capturedAt
  }

  /// A short human-readable summary suitable for a `ContextItem.summary`.
  public var summary: String {
    var parts: [String] = []
    if let name = appDisplayName ?? appBundleIdentifier { parts.append("app: \(name)") }
    if let activeFilePath { parts.append("file: \(activeFilePath)") }
    if !workspaceFolderPaths.isEmpty {
      parts.append("workspace: \(workspaceFolderPaths.joined(separator: ", "))")
    }
    return parts.isEmpty ? "no active app/workspace detected" : parts.joined(separator: "; ")
  }
}

// MARK: - Rankable

/// Common ranking inputs shared by `ContextItem` and `ReferenceCandidate` so
/// `ContextRanking` scores both with one implementation of "scope match,
/// recency, authority, confidence, direct evidence."
public protocol ContextRankable {
  var observedAt: Date { get }
  var authority: ContextAuthority { get }
  var confidence: Double { get }
  var hasDirectEvidence: Bool { get }
  var scopeMatch: Bool { get }
}

public enum ContextDestination: String, Codable, Sendable, Equatable {
  case localModel
  case remoteModel
}

/// The context transport boundary is explicit. Local-only is the safe
/// default; remote delivery is a separate, inspectable request and remains
/// sensitivity-filtered before a caller can hand it to a remote model.
public struct ContextDeliveryPolicy: Codable, Sendable, Equatable {
  public let destination: ContextDestination
  public let allowSensitive: Bool

  public init(destination: ContextDestination = .localModel, allowSensitive: Bool = false) {
    self.destination = destination
    self.allowSensitive = allowSensitive
  }

  public static let localOnly = ContextDeliveryPolicy()
  public static let remotePublicOnly = ContextDeliveryPolicy(
    destination: .remoteModel, allowSensitive: false)

  public func permits(_ sensitivity: SensitivityLevel) -> Bool {
    switch destination {
    case .localModel:
      return true
    case .remoteModel:
      switch sensitivity {
      case .publicLevel: return true
      case .internalLevel: return allowSensitive
      case .sensitive, .secret: return false
      }
    }
  }
}

// MARK: - Context item

/// One piece of content in a reconstructed context bundle, always traceable
/// via `sourceID` back to whatever produced it.
public struct ContextItem: Sendable, Equatable, Identifiable, ContextRankable {
  public let id: UUID
  public let stage: ContextRetrievalStage
  public let sourceID: ContextSourceID
  public let summary: String
  public let authority: ContextAuthority
  public let confidence: Double
  public let observedAt: Date
  public let hasDirectEvidence: Bool
  public let scopeMatch: Bool
  public let sensitivity: SensitivityLevel
  public let isRedacted: Bool
  /// Composite rank score assigned by `ContextRanking`; `0` for mandatory
  /// items that were never scored (they are never competing for budget).
  public let score: Double
  /// Provenance graph nodes that explain this item's lineage. Empty for
  /// transient sources (the utterance, conversation state, and live
  /// workspace) that have no persisted graph node.
  public let provenanceNodeIDs: [UUID]
  /// Stable, inspectable explanation of why the item survived ranking and
  /// budgeting. Phase 22 surfaces this programmatically; a visual inspector
  /// may render it later without changing the context contract.
  public let inclusionReason: String

  public init(
    id: UUID = UUID(),
    stage: ContextRetrievalStage,
    sourceID: ContextSourceID,
    summary: String,
    authority: ContextAuthority,
    confidence: Double,
    observedAt: Date,
    hasDirectEvidence: Bool,
    scopeMatch: Bool,
    sensitivity: SensitivityLevel = .internalLevel,
    isRedacted: Bool = false,
    score: Double = 0,
    provenanceNodeIDs: [UUID] = [],
    inclusionReason: String = "mandatory live context"
  ) {
    self.id = id
    self.stage = stage
    self.sourceID = sourceID
    self.summary = summary
    self.authority = authority
    self.confidence = min(max(confidence, 0), 1)
    self.observedAt = observedAt
    self.hasDirectEvidence = hasDirectEvidence
    self.scopeMatch = scopeMatch
    self.sensitivity = sensitivity
    self.isRedacted = isRedacted
    self.score = score
    self.provenanceNodeIDs = provenanceNodeIDs
    self.inclusionReason = inclusionReason
  }

  public func withScore(_ newScore: Double) -> ContextItem {
    ContextItem(
      id: id, stage: stage, sourceID: sourceID, summary: summary, authority: authority,
      confidence: confidence, observedAt: observedAt, hasDirectEvidence: hasDirectEvidence,
      scopeMatch: scopeMatch, sensitivity: sensitivity, isRedacted: isRedacted,
      score: newScore, provenanceNodeIDs: provenanceNodeIDs,
      inclusionReason: inclusionReason)
  }

  public func withExplainability(
    provenanceNodeIDs: [UUID],
    inclusionReason: String
  ) -> ContextItem {
    ContextItem(
      id: id, stage: stage, sourceID: sourceID, summary: summary, authority: authority,
      confidence: confidence, observedAt: observedAt, hasDirectEvidence: hasDirectEvidence,
      scopeMatch: scopeMatch, sensitivity: sensitivity, isRedacted: isRedacted,
      score: score, provenanceNodeIDs: provenanceNodeIDs,
      inclusionReason: inclusionReason)
  }
}

// MARK: - Context bundle

/// The minimal, sufficient context assembled for one user utterance.
public struct ContextBundle: Sendable, Equatable {
  public let sessionID: UUID
  public let utterance: String
  public let purpose: String
  public let requestingComponent: ActorID
  public let deliveryPolicy: ContextDeliveryPolicy
  public let generatedAt: Date
  /// Final items, in retrieval-sequence order, already truncated to budget.
  public let items: [ContextItem]
  /// How many optional (non-mandatory) candidates were considered before
  /// ranking/truncation.
  public let consideredCandidateCount: Int
  /// How many of those candidates were dropped to keep the bundle minimal.
  public let droppedCandidateCount: Int
  public let tokenBudget: Int
  public let estimatedTokenCount: Int
  public let exclusions: [String]
  public let unresolvedContradictions: [MemoryConflict]

  public init(
    sessionID: UUID,
    utterance: String,
    purpose: String = "turn reconstruction",
    requestingComponent: ActorID = .context,
    deliveryPolicy: ContextDeliveryPolicy = .localOnly,
    generatedAt: Date = Date(),
    items: [ContextItem],
    consideredCandidateCount: Int,
    droppedCandidateCount: Int,
    tokenBudget: Int = 0,
    estimatedTokenCount: Int = 0,
    exclusions: [String] = [],
    unresolvedContradictions: [MemoryConflict] = []
  ) {
    self.sessionID = sessionID
    self.utterance = utterance
    self.purpose = purpose
    self.requestingComponent = requestingComponent
    self.deliveryPolicy = deliveryPolicy
    self.generatedAt = generatedAt
    self.items = items
    self.consideredCandidateCount = consideredCandidateCount
    self.droppedCandidateCount = droppedCandidateCount
    self.tokenBudget = tokenBudget
    self.estimatedTokenCount = estimatedTokenCount
    self.exclusions = exclusions
    self.unresolvedContradictions = unresolvedContradictions
  }
}

// MARK: - Reference resolution

/// A candidate real-world target for a pronoun/implicit reference ("it",
/// "that", "the file", "the last one").
public struct ReferenceCandidate: Sendable, Equatable, Identifiable, ContextRankable {
  public let id: UUID
  public let sourceID: ContextSourceID
  public let description: String
  /// The capability/risk tier this candidate would be acted on with, if
  /// known. `nil` means the reference is purely informational (no action
  /// tier to guard).
  public let capability: Capability?
  public let authority: ContextAuthority
  public let confidence: Double
  public let observedAt: Date
  public let hasDirectEvidence: Bool
  public let scopeMatch: Bool
  /// Entity category used by reference phrases such as "the file".
  public let entityKind: ReferenceEntityKind
  /// Turn-local prominence (0...1), independent from wall-clock recency.
  /// Direct mentions and active selections should be more salient than
  /// background context, but salience never bypasses guarded evidence.
  public let conversationalSalience: Double
  /// Provenance nodes supporting the candidate.
  public let provenanceNodeIDs: [UUID]

  public init(
    id: UUID = UUID(),
    sourceID: ContextSourceID,
    description: String,
    capability: Capability? = nil,
    authority: ContextAuthority,
    confidence: Double,
    observedAt: Date,
    hasDirectEvidence: Bool,
    scopeMatch: Bool,
    entityKind: ReferenceEntityKind = .unknown,
    conversationalSalience: Double = 0.5,
    provenanceNodeIDs: [UUID] = []
  ) {
    self.id = id
    self.sourceID = sourceID
    self.description = description
    self.capability = capability
    self.authority = authority
    self.confidence = min(max(confidence, 0), 1)
    self.observedAt = observedAt
    self.hasDirectEvidence = hasDirectEvidence
    self.scopeMatch = scopeMatch
    self.entityKind = entityKind
    self.conversationalSalience = min(max(conversationalSalience, 0), 1)
    self.provenanceNodeIDs = provenanceNodeIDs
  }
}

public enum ReferenceEntityKind: String, Codable, Sendable, Equatable, CaseIterable {
  case file
  case application
  case task
  case decision
  case preference
  case conversationItem
  case unknown
}

/// Outcome of resolving a reference against a set of candidates.
///
/// `.blockedWeakEvidence` is distinct from `.ambiguous`: it fires when there
/// is a single clear top candidate but its action tier is guarded and the
/// evidence backing it is too weak to act on automatically — "ask or surface
/// a focused confirmation" maps `.ambiguous` to "ask which one" and
/// `.blockedWeakEvidence` to "confirm this one, explicitly."
public enum ReferenceResolution: Sendable, Equatable {
  case resolved(ReferenceCandidate)
  case ambiguous([ReferenceCandidate])
  case blockedWeakEvidence(ReferenceCandidate)
  case none
}
