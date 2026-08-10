import Foundation

// MARK: - Memory class

/// The eight memory classes from `docs/subsystems/21_MEMORY_ENGINE.md`.
public enum MemoryClass: String, Codable, Sendable, Equatable, CaseIterable {
  case ephemeralAudio
  case workingConversation
  case sessionSummary
  case taskState
  case projectFact
  case userPreference
  case proceduralKnowledge
  case auditSecurity
}

/// The origin of a requested memory write. This is deliberately narrower than
/// `MemoryProvenance`: provenance describes what was recorded, while this
/// value describes whether the caller is allowed to persist it at all.
public enum MemoryWriteSource: Codable, Sendable, Equatable {
  case explicitUser
  case verifiedToolEvidence(actor: ActorID)
  case activeDurableTask
  case approvedSummary
  case classifierDerived
  case inferred
  case modelOutput
  case untrustedExternalContent
  case rawContent
}

// MARK: - Provenance

/// How a memory record's statement came to be known.
///
/// `.inferred` exists specifically so inference is always labeled, never
/// presented as directly observed or user-stated fact — one of the Memory
/// Engine's normative rules ("Inference is labeled").
public enum MemoryProvenance: Codable, Sendable, Equatable {
  /// The user directly stated this.
  case userStated
  /// Directly observed by a named subsystem (e.g. a tool result, a file
  /// read, a policy decision) rather than asserted by the user.
  case observed(source: ActorID)
  /// Derived by inference rather than directly observed or stated.
  /// `basis` names the reasoning or signal the inference rests on.
  case inferred(basis: String)
  /// Derived deterministically by a system process (e.g. a task-state
  /// projection), not inferred from ambiguous signals.
  case systemDerived(source: ActorID)
}

// MARK: - Retention policy

/// How long a memory record may be retained before it is eligible for
/// automatic purge by `MemoryEngine.enforceRetention`.
public enum MemoryRetentionPolicy: Codable, Sendable, Equatable {
  /// Purged `seconds` after `createdAt` — e.g. an ephemeral audio buffer.
  case ephemeral(seconds: TimeInterval)
  /// Purged when the owning session ends (enforced by the caller passing
  /// the session's end time to `enforceRetention`; the engine itself has no
  /// session-lifecycle awareness).
  case sessionScoped
  /// Retained until explicitly corrected or deleted — project facts,
  /// user-approved preferences, procedural knowledge.
  case indefinite
  /// Fixed, long-lived compliance retention for audit/security records.
  /// Records under this policy can never be deleted by
  /// `MemoryEngine.deleteRecord` (only `enforceRetention`, after the
  /// retention window elapses, may remove them) — audit history must not be
  /// user-erasable on demand.
  case auditRetention(days: Int)
}

// MARK: - Scope

/// Project/task/session scoping for a memory record, per the "project and
/// task scope" field in the memory record schema.
public struct MemoryScope: Codable, Sendable, Equatable {
  public let projectID: String?
  public let taskID: UUID?
  public let sessionID: UUID?

  public init(projectID: String? = nil, taskID: UUID? = nil, sessionID: UUID? = nil) {
    self.projectID = projectID
    self.taskID = taskID
    self.sessionID = sessionID
  }

  /// No project/task/session scoping — visible regardless of scope filter.
  public static let global = MemoryScope()
}

// MARK: - Memory record

/// An immutable, append-only memory record.
///
/// There is deliberately no stored `supersededBy` field, even though the
/// memory record schema is described in terms of "supersedes/superseded-by":
/// storing a reverse pointer would require mutating an older record after
/// the fact, which breaks true append-only immutability. `supersedes` is the
/// only stored (forward) pointer; "superseded-by" is always a derived,
/// query-time relationship (`MemoryEngine.supersedingRecord(of:)`).
public struct MemoryRecord: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let memoryClass: MemoryClass
  public let subject: String
  public let statement: String
  public let evidenceReferences: [String]
  public let provenance: MemoryProvenance
  public let confidence: Double
  public let sensitivity: SensitivityLevel
  public let createdAt: Date
  public let observedAt: Date
  public let retention: MemoryRetentionPolicy
  /// Why this record is being retained. This is metadata, not authority: the
  /// provenance and evidence fields remain the source of truth for trust.
  public let purpose: String
  public let supersedes: UUID?
  public let scope: MemoryScope

  public init(
    id: UUID = UUID(),
    memoryClass: MemoryClass,
    subject: String,
    statement: String,
    evidenceReferences: [String] = [],
    provenance: MemoryProvenance,
    confidence: Double,
    sensitivity: SensitivityLevel,
    createdAt: Date = Date(),
    observedAt: Date? = nil,
    retention: MemoryRetentionPolicy,
    purpose: String = "unspecified",
    supersedes: UUID? = nil,
    scope: MemoryScope = .global
  ) {
    self.id = id
    self.memoryClass = memoryClass
    self.subject = subject
    self.statement = statement
    self.evidenceReferences = evidenceReferences
    self.provenance = provenance
    self.confidence = min(max(confidence, 0), 1)
    self.sensitivity = sensitivity
    self.createdAt = createdAt
    self.observedAt = observedAt ?? createdAt
    self.retention = retention
    self.purpose = purpose
    self.supersedes = supersedes
    self.scope = scope
  }
}

/// A request to append a new memory record, before an ID/timestamp is
/// assigned by `MemoryEngine`.
public struct MemoryRecordDraft: Sendable, Equatable {
  public let memoryClass: MemoryClass
  public let subject: String
  public let statement: String
  public let evidenceReferences: [String]
  public let provenance: MemoryProvenance
  public let confidence: Double
  public let sensitivity: SensitivityLevel
  public let observedAt: Date?
  public let retention: MemoryRetentionPolicy
  public let purpose: String
  public let supersedes: UUID?
  public let scope: MemoryScope

  public init(
    memoryClass: MemoryClass,
    subject: String,
    statement: String,
    evidenceReferences: [String] = [],
    provenance: MemoryProvenance,
    confidence: Double = 1.0,
    sensitivity: SensitivityLevel,
    observedAt: Date? = nil,
    retention: MemoryRetentionPolicy,
    purpose: String = "unspecified",
    supersedes: UUID? = nil,
    scope: MemoryScope = .global
  ) {
    self.memoryClass = memoryClass
    self.subject = subject
    self.statement = statement
    self.evidenceReferences = evidenceReferences
    self.provenance = provenance
    self.confidence = confidence
    self.sensitivity = sensitivity
    self.observedAt = observedAt
    self.retention = retention
    self.purpose = purpose
    self.supersedes = supersedes
    self.scope = scope
  }
}

/// A policy-aware request to persist memory. Callers that are crossing a
/// subsystem boundary should use this type instead of treating a plain draft
/// as implicit authorization to retain user data.
public struct MemoryWriteRequest: Sendable, Equatable {
  public let draft: MemoryRecordDraft
  public let source: MemoryWriteSource

  public init(draft: MemoryRecordDraft, source: MemoryWriteSource) {
    self.draft = draft
    self.source = source
  }
}

public enum PreferenceResponseLength: String, Codable, Sendable, Equatable, CaseIterable {
  case concise
  case balanced
  case detailed
}

public struct PreferenceQuietHours: Codable, Sendable, Equatable {
  public let startHour: Int
  public let endHour: Int

  public init(startHour: Int, endHour: Int) {
    self.startHour = startHour
    self.endHour = endHour
  }

  public func validate() throws(AuraError) {
    guard (0..<24).contains(startHour), (0..<24).contains(endHour) else {
      throw AuraError.memoryError("quiet hours must use 0...23 hour values")
    }
  }
}

/// User-controlled personalization data. It is intentionally a bounded,
/// typed profile rather than an arbitrary key/value memory bag.
public struct UserPreferenceProfile: Codable, Sendable, Equatable {
  public var preferredLanguage: String
  public var responseLength: PreferenceResponseLength
  public var browserAccount: String?
  public var mailAccount: String?
  public var calendarAccount: String?
  public var codingBackend: String?
  public var codingModel: String?
  public var workingDirectories: [String]
  public var projects: [String]
  public var voicePreference: String?
  public var activationPreference: String?
  public var localOnly: Bool
  public var quietHours: PreferenceQuietHours?
  public var enabledMemoryClasses: Set<MemoryClass>
  public var retentionOverrides: [MemoryClass: MemoryRetentionPolicy]

  public init(
    preferredLanguage: String = "tr-TR",
    responseLength: PreferenceResponseLength = .balanced,
    browserAccount: String? = nil,
    mailAccount: String? = nil,
    calendarAccount: String? = nil,
    codingBackend: String? = nil,
    codingModel: String? = nil,
    workingDirectories: [String] = [],
    projects: [String] = [],
    voicePreference: String? = nil,
    activationPreference: String? = nil,
    localOnly: Bool = true,
    quietHours: PreferenceQuietHours? = nil,
    enabledMemoryClasses: Set<MemoryClass> = Set(
      MemoryClass.allCases.filter { $0 != .auditSecurity }),
    retentionOverrides: [MemoryClass: MemoryRetentionPolicy] = [:]
  ) {
    self.preferredLanguage = preferredLanguage
    self.responseLength = responseLength
    self.browserAccount = browserAccount
    self.mailAccount = mailAccount
    self.calendarAccount = calendarAccount
    self.codingBackend = codingBackend
    self.codingModel = codingModel
    self.workingDirectories = workingDirectories
    self.projects = projects
    self.voicePreference = voicePreference
    self.activationPreference = activationPreference
    self.localOnly = localOnly
    self.quietHours = quietHours
    self.enabledMemoryClasses = enabledMemoryClasses
    self.retentionOverrides = retentionOverrides
  }

  public func validate() throws(AuraError) {
    guard !preferredLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.memoryError("preferred language must not be empty")
    }
    guard !enabledMemoryClasses.contains(.auditSecurity) else {
      throw AuraError.memoryError("audit/security memory cannot be user-enabled or disabled")
    }
    guard
      workingDirectories.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    else {
      throw AuraError.memoryError("working directory preferences must not be empty")
    }
    try quietHours?.validate()
  }
}

/// Non-user policy bounds. A preference may narrow these bounds but can never
/// widen them (for example, enabling cloud context while the machine policy is
/// local-only).
public struct PreferencePolicyBounds: Sendable, Equatable {
  public let cloudContextAllowed: Bool

  public init(cloudContextAllowed: Bool = false) {
    self.cloudContextAllowed = cloudContextAllowed
  }

  public func validate(_ profile: UserPreferenceProfile) throws(AuraError) {
    try profile.validate()
    guard profile.localOnly || cloudContextAllowed else {
      throw AuraError.permissionDenied(
        "user preference cannot enable remote context while machine policy is local-only")
    }
  }
}

// MARK: - Conflict record

/// How a detected memory conflict was resolved. `nil` on `MemoryConflict`
/// means still unresolved.
public enum MemoryConflictResolution: Codable, Sendable, Equatable {
  /// The new record was accepted as an explicit correction of the existing
  /// one (a subsequent `supersedes`-linked record was appended).
  case supersededExisting
  /// The existing record was kept; the new, conflicting record stands as a
  /// disagreement rather than a correction.
  case keptExisting(reason: String)
  /// Both records are legitimately valid simultaneously (e.g. genuinely
  /// different scopes that were not distinguished in the subject key).
  case bothRetained(reason: String)
}

/// An append-only record of a detected contradiction between two memory
/// records sharing the same `(memoryClass, subject, scope)` key.
///
/// Unlike `MemoryRecord`, `resolution` is mutable in place — it represents
/// current triage status of an operational conflict, not a memory statement
/// whose history must itself be preserved verbatim.
public struct MemoryConflict: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let memoryClass: MemoryClass
  public let subject: String
  public let existingRecordID: UUID
  public let newRecordID: UUID
  public let detectedAt: Date
  public var resolution: MemoryConflictResolution?

  public init(
    id: UUID = UUID(),
    memoryClass: MemoryClass,
    subject: String,
    existingRecordID: UUID,
    newRecordID: UUID,
    detectedAt: Date = Date(),
    resolution: MemoryConflictResolution? = nil
  ) {
    self.id = id
    self.memoryClass = memoryClass
    self.subject = subject
    self.existingRecordID = existingRecordID
    self.newRecordID = newRecordID
    self.detectedAt = detectedAt
    self.resolution = resolution
  }
}

// MARK: - Append outcome

/// Result of `MemoryEngine.append`.
public enum MemoryAppendOutcome: Sendable, Equatable {
  /// Recorded with no detected conflict (including intentional
  /// supersession, which is never treated as a surprise conflict).
  case recorded(MemoryRecord)
  /// Recorded, but a conflict was also detected and recorded against a
  /// prior active record for the same key.
  case recordedWithConflict(MemoryRecord, MemoryConflict)
}

// MARK: - Deletion and export

/// Proof that a memory record was deleted, without preserving the deleted
/// content itself — "corrections/deletions preserve provenance" without
/// defeating the purpose of deletion.
public struct MemoryDeletionReceipt: Sendable, Equatable {
  public let recordID: UUID
  public let memoryClass: MemoryClass
  public let reason: String
  public let deletedAt: Date

  public init(recordID: UUID, memoryClass: MemoryClass, reason: String, deletedAt: Date = Date()) {
    self.recordID = recordID
    self.memoryClass = memoryClass
    self.reason = reason
    self.deletedAt = deletedAt
  }
}

/// A user-facing export bundle for inspection/export of non-audit memory.
public struct MemoryExportBundle: Sendable, Equatable {
  public let generatedAt: Date
  public let records: [MemoryRecord]
  public let conflicts: [MemoryConflict]

  public init(generatedAt: Date = Date(), records: [MemoryRecord], conflicts: [MemoryConflict]) {
    self.generatedAt = generatedAt
    self.records = records
    self.conflicts = conflicts
  }
}

// MARK: - Query filter

/// Filter used by `MemoryEngine` query/projection/export methods.
public struct MemoryQuery: Sendable, Equatable {
  public let memoryClass: MemoryClass?
  public let subject: String?
  public let scope: MemoryScope?
  public let includeSuperseded: Bool

  public init(
    memoryClass: MemoryClass? = nil,
    subject: String? = nil,
    scope: MemoryScope? = nil,
    includeSuperseded: Bool = false
  ) {
    self.memoryClass = memoryClass
    self.subject = subject
    self.scope = scope
    self.includeSuperseded = includeSuperseded
  }

  public static let all = MemoryQuery(includeSuperseded: true)
}
