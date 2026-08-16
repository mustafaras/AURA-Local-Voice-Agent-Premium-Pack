import AuraCore
import Foundation
import Testing

@testable import AuraPolicy

/// SP-006: pins the production default grant posture. `AuraKernel` seeds
/// `DefaultPolicyGrants.all` into a `PolicyEngine` built from the unmodified
/// production `PolicyConfiguration()`; these tests construct exactly that
/// combination so the live-path policy decision for every seeded capability
/// is verified without launching the app (which no test bundle can import).
@Suite("DefaultPolicyGrants (production posture)")
struct DefaultPolicyGrantsTests {
  private func makeProductionEngine() async throws -> PolicyEngine {
    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AuraPolicyTests", category: "default-grants"))
    // The exact production configuration: PolicyConfiguration() defaults,
    // no allow-by-default widening.
    let engine = try await PolicyEngine(
      configuration: PolicyConfiguration(), eventBus: bus, store: nil)
    for grant in DefaultPolicyGrants.all {
      try await engine.issueGrant(grant)
    }
    return engine
  }

  private func evaluate(
    _ capability: Capability, engine: PolicyEngine, target: PolicyTarget = .empty
  ) async -> PolicyDecision {
    await engine.evaluate(
      PolicyEvaluationRequest(
        capability: capability, actor: .user, target: target, sessionID: UUID(),
        correlationID: UUID(), causationID: UUID()))
  }

  @Test("SP-006: filesystem/URL capabilities are allowed by seeded grants")
  func filesystemAndURLCapabilitiesAllowed() async throws {
    let engine = try await makeProductionEngine()
    for capability in [Capability.fileOpen, .fileReveal, .urlOpen] {
      let decision = await evaluate(capability, engine: engine)
      guard case .allow = decision else {
        Issue.record("Expected .allow for \(capability.identifier), got \(decision)")
        return
      }
    }
  }

  @Test("appActivate stays allowed without confirmation")
  func appActivateAllowed() async throws {
    let engine = try await makeProductionEngine()
    let decision = await evaluate(.appActivate, engine: engine)
    guard case .allow = decision else {
      Issue.record("Expected .allow for appActivate, got \(decision)")
      return
    }
  }

  @Test("appTerminate requires confirmation under the seeded grant")
  func appTerminateConfirms() async throws {
    let engine = try await makeProductionEngine()
    let decision = await evaluate(.appTerminate, engine: engine)
    guard case .confirm = decision else {
      Issue.record("Expected .confirm for appTerminate, got \(decision)")
      return
    }
  }

  @Test("shellExec requires confirmation on every request")
  func shellExecConfirms() async throws {
    let engine = try await makeProductionEngine()
    let decision = await evaluate(.shellExec, engine: engine)
    guard case .confirm = decision else {
      Issue.record("Expected .confirm for shellExec, got \(decision)")
      return
    }
  }

  @Test("local Ollama inference stays allowed; no cloud-inference grant exists")
  func ollamaGrants() async throws {
    let engine = try await makeProductionEngine()
    let decision = await evaluate(.agentOllamaLocalInference, engine: engine)
    guard case .allow = decision else {
      Issue.record("Expected .allow for agentOllamaLocalInference, got \(decision)")
      return
    }
    #expect(
      DefaultPolicyGrants.all.contains { $0.capability == .agentOllamaLocalInference })
    // There must be no cloud inference capability grant to drift into.
    #expect(
      !DefaultPolicyGrants.all.contains {
        $0.capability.identifier.lowercased().contains("cloud")
      })
  }

  @Test("ungranted destructive capability is still denied by default")
  func ungrantedDestructiveDenied() async throws {
    let engine = try await makeProductionEngine()
    let decision = await evaluate(.fileDelete, engine: engine)
    guard case .deny = decision else {
      Issue.record("Expected .deny for ungranted fileDelete, got \(decision)")
      return
    }
  }

  @Test("ungranted reversible capability outside the seeded set is still denied")
  func ungrantedReversibleDenied() async throws {
    let engine = try await makeProductionEngine()
    // .appHide is reversible-tier but intentionally not seeded; deny-by-default
    // must still hold for reversible capabilities with no grant.
    let decision = await evaluate(.appHide, engine: engine)
    guard case .deny = decision else {
      Issue.record("Expected .deny for ungranted appHide, got \(decision)")
      return
    }
  }

  @Test("grant list contains exactly the intended capabilities, each once")
  func grantInventoryIsExact() {
    let identifiers = DefaultPolicyGrants.all.map { $0.capability.identifier }
    #expect(Set(identifiers).count == identifiers.count)
    #expect(
      Set(identifiers) == [
        Capability.appActivate.identifier,
        Capability.appTerminate.identifier,
        Capability.shellExec.identifier,
        Capability.agentCodexRun.identifier,
        Capability.agentClaudeRun.identifier,
        Capability.agentCopilotRun.identifier,
        Capability.agentOllamaLocalInference.identifier,
        Capability.fileOpen.identifier,
        Capability.fileReveal.identifier,
        Capability.urlOpen.identifier,
      ])
  }
}
