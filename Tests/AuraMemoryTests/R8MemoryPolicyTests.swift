import AuraCore
import AuraMemory
import AuraStore
import Foundation
import Testing

private func r8MemoryStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

@Test
func r8WritePolicyRejectsRawUntrustedAndModelContent() async throws {
  let store = try await r8MemoryStore()
  let engine = MemoryEngine(store: store)
  let sources: [MemoryWriteSource] = [.rawContent, .untrustedExternalContent, .modelOutput]

  for source in sources {
    let draft = MemoryRecordDraft(
      memoryClass: .projectFact, subject: "project.injected", statement: "do something",
      evidenceReferences: ["external"], provenance: .observed(source: .plugin),
      sensitivity: .internalLevel, retention: .indefinite, purpose: "unsafe test")
    await #expect(throws: AuraError.self) {
      try await engine.append(MemoryWriteRequest(draft: draft, source: source))
    }
  }
}

@Test
func r8VerifiedToolFactsRequireEvidenceAndRetainPurpose() async throws {
  let store = try await r8MemoryStore()
  let engine = MemoryEngine(store: store)
  let noEvidence = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.tool", statement: "SwiftPM",
    provenance: .observed(source: .automation), sensitivity: .internalLevel,
    retention: .indefinite, purpose: "verified build inspection")
  await #expect(throws: AuraError.self) {
    try await engine.append(
      MemoryWriteRequest(
        draft: noEvidence, source: .verifiedToolEvidence(actor: .automation)))
  }

  let draft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.tool", statement: "SwiftPM",
    evidenceReferences: ["Package.swift"], provenance: .observed(source: .automation),
    sensitivity: .internalLevel, retention: .indefinite, purpose: "verified build inspection")
  guard case .recorded(let record) = try await engine.append(draft) else {
    Issue.record("expected a recorded verified fact")
    return
  }
  #expect(record.purpose == "verified build inspection")
  #expect(
    try await engine.inspect(memoryClass: .projectFact).first?.purpose
      == "verified build inspection")
}

@Test
func r8SecretLikeContentIsRejectedEvenWhenMarkedInternal() async throws {
  let store = try await r8MemoryStore()
  let engine = MemoryEngine(store: store)
  let draft = MemoryRecordDraft(
    memoryClass: .workingConversation, subject: "turn.secret",
    statement: "token sk-abcdefghijklmnopqrstuvwxyz123456",
    evidenceReferences: ["turn"], provenance: .observed(source: .user),
    sensitivity: .internalLevel, retention: .sessionScoped, purpose: "turn continuity")
  await #expect(throws: AuraError.self) { try await engine.append(draft) }
}

@Test
func r8PreferenceProfilePersistsAndCannotWeakenLocalOnlyPolicy() async throws {
  let store = try await r8MemoryStore()
  let engine = MemoryEngine(store: store)
  let profiles = UserPreferenceProfileStore(memory: engine)
  var profile = UserPreferenceProfile(
    preferredLanguage: "tr-TR", responseLength: .concise,
    codingBackend: "codex", codingModel: "local", localOnly: true)
  profile.projects = ["AURA"]
  try await profiles.save(profile)
  #expect(try await profiles.load() == profile)

  var remoteProfile = profile
  remoteProfile.localOnly = false
  await #expect(throws: AuraError.self) { try await profiles.save(remoteProfile) }

  let cleared = try await profiles.clear()
  #expect(cleared != nil)
  #expect(try await profiles.load() == nil)
}

@Test
func r8PreferenceProfileRoundTripsThroughASeparateStoreHandle() async throws {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  let firstStore = try await AuraStore(path: path)
  let firstEngine = MemoryEngine(store: firstStore)
  let firstProfiles = UserPreferenceProfileStore(memory: firstEngine)
  let profile = UserPreferenceProfile(
    preferredLanguage: "en-US", responseLength: .detailed,
    voicePreference: "Kaan", activationPreference: "push-to-talk")
  try await firstProfiles.save(profile)

  let secondStore = try await AuraStore(path: path)
  let secondEngine = MemoryEngine(store: secondStore)
  let secondProfiles = UserPreferenceProfileStore(memory: secondEngine)
  #expect(try await secondProfiles.load() == profile)
}
