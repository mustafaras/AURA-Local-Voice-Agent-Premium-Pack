import AuraCore
import AuraMemory
import AuraStore
import Foundation
import Testing

@testable import AuraIntent

private func makeMemoryBackedEngine() async throws -> (IntentEngine, MemoryEngine) {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  let store = try await AuraStore(path: path)
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraIntentTests", category: "tool-evidence"))
  let memory = MemoryEngine(store: store, eventBus: bus)
  let engine = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(), memoryEngine: memory, eventBus: bus,
    sessionID: UUID())
  return (engine, memory)
}

private func makeContext() -> TurnContext {
  TurnContext(
    sessionID: UUID(), activationSource: .text, actor: .user,
    authority: .userUtterance, sensitivity: .sensitive)
}

private func makeObservation(
  factKey: String = "shell.execute:/usr/bin/git rev-parse --abbrev-ref HEAD",
  statement: String
) -> ToolObservation {
  ToolObservation(
    toolID: "shell.execute",
    factKey: factKey,
    statement: statement,
    evidenceReferences: ["tool:shell.execute", "execution:\(UUID().uuidString)"],
    sourceActor: .user)
}

@Suite("SP-019 verified tool evidence becomes project fact")
struct SP019ToolEvidenceMemoryTests {
  @Test("a verified tool observation is retained as an observed project fact")
  func observationBecomesProjectFact() async throws {
    let (engine, memory) = try await makeMemoryBackedEngine()

    await engine.persistToolObservationAsProjectFact(
      makeObservation(statement: "`/usr/bin/git rev-parse --abbrev-ref HEAD` reported: main"),
      context: makeContext())

    let records = try await memory.inspect()
    let fact = try #require(records.first { $0.memoryClass == .projectFact })
    #expect(fact.subject == "shell.execute:/usr/bin/git rev-parse --abbrev-ref HEAD")
    #expect(fact.statement.contains("main"))
    #expect(fact.purpose == "verified project fact derived from tool evidence")
    #expect(!fact.evidenceReferences.isEmpty)
    // The provenance must name the observing subsystem: a tool-derived fact
    // may never be recorded as user-stated or inferred.
    guard case .observed = fact.provenance else {
      Issue.record("expected .observed provenance, got \(fact.provenance)")
      return
    }
  }

  @Test("a changed answer for the same fact raises a contradiction")
  func differingObservationRaisesContradiction() async throws {
    let (engine, memory) = try await makeMemoryBackedEngine()
    let context = makeContext()

    await engine.persistToolObservationAsProjectFact(
      makeObservation(statement: "`git rev-parse --abbrev-ref HEAD` reported: main"),
      context: context)
    await engine.persistToolObservationAsProjectFact(
      makeObservation(statement: "`git rev-parse --abbrev-ref HEAD` reported: release"),
      context: context)

    let conflicts = try await memory.conflicts()
    #expect(conflicts.count == 1)
    let conflict = try #require(conflicts.first)
    #expect(conflict.subject == "shell.execute:/usr/bin/git rev-parse --abbrev-ref HEAD")
    #expect(conflict.resolution == nil)
    // Neither belief is silently discarded.
    let facts = try await memory.inspect().filter { $0.memoryClass == .projectFact }
    #expect(facts.count == 2)
  }

  @Test("re-observing the same answer is not a contradiction")
  func identicalObservationDoesNotConflict() async throws {
    let (engine, memory) = try await makeMemoryBackedEngine()
    let context = makeContext()
    let statement = "`git rev-parse --abbrev-ref HEAD` reported: main"

    await engine.persistToolObservationAsProjectFact(
      makeObservation(statement: statement), context: context)
    await engine.persistToolObservationAsProjectFact(
      makeObservation(statement: statement), context: context)

    #expect(try await memory.conflicts().isEmpty)
  }

  @Test("observations of different facts never collide")
  func differentFactKeysDoNotConflict() async throws {
    let (engine, memory) = try await makeMemoryBackedEngine()
    let context = makeContext()

    await engine.persistToolObservationAsProjectFact(
      makeObservation(factKey: "shell.execute:git branch", statement: "reported: main"),
      context: context)
    await engine.persistToolObservationAsProjectFact(
      makeObservation(factKey: "shell.execute:swift --version", statement: "reported: 6.4.0"),
      context: context)

    #expect(try await memory.conflicts().isEmpty)
    #expect(try await memory.inspect().filter { $0.memoryClass == .projectFact }.count == 2)
  }

  @Test("secret-looking tool output is refused rather than retained")
  func secretLikeOutputIsNotRetained() async throws {
    let (engine, memory) = try await makeMemoryBackedEngine()

    await engine.persistToolObservationAsProjectFact(
      makeObservation(statement: "reported: sk-abcdefghijklmnopqrst0123456789"),
      context: makeContext())

    #expect(try await memory.inspect().filter { $0.memoryClass == .projectFact }.isEmpty)
  }

  @Test("tool output is reduced to a bounded single line")
  func boundedOutputIsSingleLineAndPrintable() {
    #expect(ToolObservation.boundedOutput("\n\nmain\norigin/main\n") == "main")
    #expect(ToolObservation.boundedOutput("  spaced  \nsecond") == "spaced")
    #expect(ToolObservation.boundedOutput("a\u{7F}b\u{01}c") == "abc")
    #expect(ToolObservation.boundedOutput("") == "")
    #expect(ToolObservation.boundedOutput(String(repeating: "x", count: 500)).count == 200)
  }
}
