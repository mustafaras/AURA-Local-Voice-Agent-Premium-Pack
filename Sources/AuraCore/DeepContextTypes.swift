import Foundation

/// The mechanically observable Phase 22 pipeline.
public enum ContextBuilderStage: String, Codable, Sendable, Equatable, CaseIterable {
  case utteranceParse
  case intentSchema
  case entityExtraction
  case scopeFilter
  case evidenceRank
  case ambiguityCheck
  case finalBundle
}

public struct ContextPipelineTrace: Sendable, Equatable {
  public let stage: ContextBuilderStage
  public let inputCount: Int
  public let outputCount: Int
  public let detail: String

  public init(stage: ContextBuilderStage, inputCount: Int, outputCount: Int, detail: String) {
    self.stage = stage
    self.inputCount = inputCount
    self.outputCount = outputCount
    self.detail = detail
  }
}

public struct ParsedContextUtterance: Sendable, Equatable {
  public let normalized: String
  public let tokens: [String]
  public let implicitReference: String?

  public init(normalized: String, tokens: [String], implicitReference: String?) {
    self.normalized = normalized
    self.tokens = tokens
    self.implicitReference = implicitReference
  }
}

/// Dependency-neutral representation of the already-typed intent. The
/// `AuraContext` module must not depend back on `AuraIntent`.
public struct ContextIntentSchema: Sendable, Equatable {
  public let name: String
  public let capability: Capability?
  public let confidence: Double
  public let entityHints: [String]

  public init(
    name: String,
    capability: Capability? = nil,
    confidence: Double,
    entityHints: [String] = []
  ) {
    self.name = name
    self.capability = capability
    self.confidence = min(max(confidence, 0), 1)
    self.entityHints = entityHints
  }
}

public struct ExtractedContextEntity: Sendable, Equatable, Identifiable {
  public let id: UUID
  public let kind: ReferenceEntityKind
  public let label: String
  public let sourceID: ContextSourceID
  public let provenanceNodeIDs: [UUID]
  public let confidence: Double

  public init(
    id: UUID = UUID(),
    kind: ReferenceEntityKind,
    label: String,
    sourceID: ContextSourceID,
    provenanceNodeIDs: [UUID] = [],
    confidence: Double
  ) {
    self.id = id
    self.kind = kind
    self.label = label
    self.sourceID = sourceID
    self.provenanceNodeIDs = provenanceNodeIDs
    self.confidence = min(max(confidence, 0), 1)
  }
}

/// Per-turn, non-persistent user control over what enters the model bundle.
/// Exclusion wins over ordinary retrieval; explicit inclusions are still
/// subject to sensitivity, scope, and token budgets.
public struct ContextInclusionOverride: Sendable, Equatable {
  public let excludedSourceIDs: Set<ContextSourceID>
  public let includedMemoryRecordIDs: Set<UUID>

  public init(
    excludedSourceIDs: Set<ContextSourceID> = [],
    includedMemoryRecordIDs: Set<UUID> = []
  ) {
    self.excludedSourceIDs = excludedSourceIDs
    self.includedMemoryRecordIDs = includedMemoryRecordIDs
  }

  public static let none = ContextInclusionOverride()
}

public struct DeepContextRequest: Sendable, Equatable {
  public let utterance: String
  public let sessionID: UUID
  public let purpose: String
  public let requestingComponent: ActorID
  public let conversationState: ConversationState
  public let intent: ContextIntentSchema
  public let pendingConfirmation: PolicyConfirmationChallenge?
  public let pendingTask: TaskStatus?
  public let activeWorkspace: ActiveWorkspaceSnapshot?
  public let scope: MemoryScope
  public let referenceCandidates: [ReferenceCandidate]
  public let explicitlyConfirmedTargetID: UUID?
  public let inclusionOverride: ContextInclusionOverride
  public let deliveryPolicy: ContextDeliveryPolicy
  public let referenceDate: Date

  public init(
    utterance: String,
    sessionID: UUID,
    purpose: String = "turn reconstruction",
    requestingComponent: ActorID = .context,
    conversationState: ConversationState,
    intent: ContextIntentSchema,
    pendingConfirmation: PolicyConfirmationChallenge? = nil,
    pendingTask: TaskStatus? = nil,
    activeWorkspace: ActiveWorkspaceSnapshot? = nil,
    scope: MemoryScope = .global,
    referenceCandidates: [ReferenceCandidate] = [],
    explicitlyConfirmedTargetID: UUID? = nil,
    inclusionOverride: ContextInclusionOverride = .none,
    deliveryPolicy: ContextDeliveryPolicy = .localOnly,
    referenceDate: Date = Date()
  ) {
    self.utterance = utterance
    self.sessionID = sessionID
    self.purpose = purpose
    self.requestingComponent = requestingComponent
    self.conversationState = conversationState
    self.intent = intent
    self.pendingConfirmation = pendingConfirmation
    self.pendingTask = pendingTask
    self.activeWorkspace = activeWorkspace
    self.scope = scope
    self.referenceCandidates = referenceCandidates
    self.explicitlyConfirmedTargetID = explicitlyConfirmedTargetID
    self.inclusionOverride = inclusionOverride
    self.deliveryPolicy = deliveryPolicy
    self.referenceDate = referenceDate
  }
}

public struct ReferenceGraphNode: Sendable, Equatable {
  public let candidate: ReferenceCandidate
  public let score: Double
  public let lexicalMatch: Bool
  public let explicitlyConfirmed: Bool

  public init(
    candidate: ReferenceCandidate,
    score: Double,
    lexicalMatch: Bool,
    explicitlyConfirmed: Bool
  ) {
    self.candidate = candidate
    self.score = score
    self.lexicalMatch = lexicalMatch
    self.explicitlyConfirmed = explicitlyConfirmed
  }
}

public struct ReferenceResolutionGraph: Sendable, Equatable {
  public let reference: String
  public let nodes: [ReferenceGraphNode]

  public init(reference: String, nodes: [ReferenceGraphNode]) {
    self.reference = reference
    self.nodes = nodes
  }
}

public struct ContextInspectionItem: Sendable, Equatable {
  public let sourceID: ContextSourceID
  public let confidence: Double
  public let score: Double
  public let provenanceNodeIDs: [UUID]
  public let inclusionReason: String
  public let estimatedTokens: Int

  public init(item: ContextItem, estimatedTokens: Int) {
    self.sourceID = item.sourceID
    self.confidence = item.confidence
    self.score = item.score
    self.provenanceNodeIDs = item.provenanceNodeIDs
    self.inclusionReason = item.inclusionReason
    self.estimatedTokens = estimatedTokens
  }
}

public struct DeepContextResult: Sendable, Equatable {
  public let parsedUtterance: ParsedContextUtterance
  public let intent: ContextIntentSchema
  public let entities: [ExtractedContextEntity]
  public let referenceGraph: ReferenceResolutionGraph?
  public let referenceResolution: ReferenceResolution
  public let bundle: ContextBundle
  public let inspection: [ContextInspectionItem]
  public let trace: [ContextPipelineTrace]
  public let estimatedTokenCount: Int
  public let elapsedSeconds: Double

  public init(
    parsedUtterance: ParsedContextUtterance,
    intent: ContextIntentSchema,
    entities: [ExtractedContextEntity],
    referenceGraph: ReferenceResolutionGraph?,
    referenceResolution: ReferenceResolution,
    bundle: ContextBundle,
    inspection: [ContextInspectionItem],
    trace: [ContextPipelineTrace],
    estimatedTokenCount: Int,
    elapsedSeconds: Double
  ) {
    self.parsedUtterance = parsedUtterance
    self.intent = intent
    self.entities = entities
    self.referenceGraph = referenceGraph
    self.referenceResolution = referenceResolution
    self.bundle = bundle
    self.inspection = inspection
    self.trace = trace
    self.estimatedTokenCount = estimatedTokenCount
    self.elapsedSeconds = elapsedSeconds
  }
}
