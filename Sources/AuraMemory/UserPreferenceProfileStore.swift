import AuraCore
import Foundation

/// Restart-safe, user-controlled storage for the bounded preference profile.
/// The profile is one supersession-linked user-preference record so correction,
/// export, provenance, and deletion continue to use the existing memory
/// controls instead of introducing a second persistence path.
public actor UserPreferenceProfileStore {
  public static let subject = "user.preference.profile"

  private let memory: MemoryEngine
  private let policyBounds: PreferencePolicyBounds

  public init(
    memory: MemoryEngine,
    policyBounds: PreferencePolicyBounds = PreferencePolicyBounds()
  ) {
    self.memory = memory
    self.policyBounds = policyBounds
  }

  public func load() async throws(AuraError) -> UserPreferenceProfile? {
    guard
      let record = try await memory.currentState(
        memoryClass: .userPreference, subject: Self.subject
      ).first
    else { return nil }
    do {
      let data = Data(record.statement.utf8)
      let profile = try JSONDecoder().decode(UserPreferenceProfile.self, from: data)
      try policyBounds.validate(profile)
      return profile
    } catch let error as AuraError {
      throw error
    } catch {
      throw AuraError.memoryError(
        "stored preference profile is invalid: (error.localizedDescription)")
    }
  }

  @discardableResult
  public func save(
    _ profile: UserPreferenceProfile,
    actor: ActorID = .user,
    sessionID: UUID = UUID(),
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> UserPreferenceProfile {
    try policyBounds.validate(profile)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data: Data
    do {
      data = try encoder.encode(profile)
    } catch {
      throw AuraError.serializationError("failed to encode user preference profile")
    }

    let current = try await memory.currentState(
      memoryClass: .userPreference, subject: Self.subject
    ).first
    guard let statement = String(bytes: data, encoding: .utf8) else {
      throw AuraError.serializationError("failed to encode user preference profile as UTF-8")
    }
    let draft = MemoryRecordDraft(
      memoryClass: .userPreference,
      subject: Self.subject,
      statement: statement,
      evidenceReferences: ["user-preference:(sessionID.uuidString)"],
      provenance: .userStated,
      confidence: 1.0,
      sensitivity: .internalLevel,
      retention: .indefinite,
      purpose: "user-controlled personalization profile",
      supersedes: current?.id)
    _ = try await memory.append(
      MemoryWriteRequest(draft: draft, source: .explicitUser), actor: actor,
      sessionID: sessionID, correlationID: correlationID)
    return profile
  }

  @discardableResult
  public func clear(actor: ActorID = .user) async throws(AuraError) -> MemoryDeletionReceipt? {
    guard
      let record = try await memory.currentState(
        memoryClass: .userPreference, subject: Self.subject
      ).first
    else { return nil }
    return try await memory.deleteRecord(
      id: record.id, reason: "user cleared preference profile", actor: actor)
  }
}
