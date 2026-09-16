import AuraCore
import AuraPolicy
import Foundation
import Testing

@testable import AuraIntent

/// ADR-064 (PA-0 G0-3): every capability the product registers must answer
/// `.allow` — with no confirmation challenge — for the owner actor against the
/// exact production seed set. This turns the SP-006 / SP-030 defect class
/// ("registered and implemented, but denied before reaching its adapter
/// because nothing seeded a grant") into a failing test instead of a live
/// discovery.
///
/// Two registries are covered: the manifests `InitialCapabilitySet` exposes
/// (each names one `requiredCapability`), and the per-step capabilities the
/// computer-use loop evaluates through `Capability.forComputerUse(intent:)` —
/// which the manifests do not name, because `computerUse.run` is the session
/// capability, not the step capability.
@Suite("OwnerGrantCoverage (ADR-064)")
struct OwnerGrantCoverageTests {
  private func makeProductionEngine() async throws -> PolicyEngine {
    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AuraIntentTests", category: "owner-grant-coverage"))
    // The exact production combination: unmodified PolicyConfiguration()
    // plus DefaultPolicyGrants.all, the way AuraKernel seeds it.
    let engine = try await PolicyEngine(
      configuration: PolicyConfiguration(), eventBus: bus, store: nil)
    for grant in DefaultPolicyGrants.all {
      try await engine.issueGrant(grant)
    }
    return engine
  }

  /// The narrowest honest target for a capability whose seeded grant is
  /// pattern-scoped; `.empty` for everything else. A scoped capability with
  /// an out-of-scope target must still be denied — that is a separate,
  /// existing test in `DefaultPolicyGrantsTests` and is not weakened here.
  private func inScopeTarget(for capability: Capability) -> PolicyTarget {
    switch capability {
    case .fileOpen, .fileReveal:
      let inRoot = (DeclaredFileRoots.all[0] as NSString).appendingPathComponent("note.txt")
      return PolicyTarget(filePath: inRoot)
    case .urlOpen:
      return PolicyTarget(networkHost: "example.com", urlScheme: "https")
    default:
      return .empty
    }
  }

  private func evaluate(
    _ capability: Capability, engine: PolicyEngine
  ) async -> PolicyDecision {
    await engine.evaluate(
      PolicyEvaluationRequest(
        capability: capability, actor: .user, target: inScopeTarget(for: capability),
        sessionID: UUID(), correlationID: UUID(), causationID: UUID()))
  }

  @Test("every manifest's requiredCapability allows the owner with no challenge")
  func everyManifestCapabilityAllowsOwner() async throws {
    let engine = try await makeProductionEngine()
    var gaps: [String] = []
    for (manifest, _) in InitialCapabilitySet.manifests() {
      let decision = await evaluate(manifest.requiredCapability, engine: engine)
      guard case .allow = decision else {
        gaps.append(
          "\(manifest.id) → \(manifest.requiredCapability.identifier) "
            + "[\(manifest.requiredCapability.riskTier)] got \(decision)")
        continue
      }
    }
    #expect(gaps.isEmpty, Comment(rawValue: "owner-denied manifests:\n" + gaps.joined(separator: "\n")))
  }

  @Test("every computer-use step capability allows the owner with no challenge")
  func everyComputerUseStepCapabilityAllowsOwner() async throws {
    let engine = try await makeProductionEngine()
    var gaps: [String] = []
    for intent in ComputerUseSemanticIntent.allCases {
      let capability = Capability.forComputerUse(intent: intent)
      let decision = await evaluate(capability, engine: engine)
      guard case .allow = decision else {
        gaps.append("\(intent.rawValue) → \(capability.identifier) got \(decision)")
        continue
      }
    }
    #expect(
      gaps.isEmpty,
      Comment(rawValue: "owner-denied computer-use steps:\n" + gaps.joined(separator: "\n")))
  }

  @Test("the screen-capture capability the loop's observe phase evaluates allows the owner")
  func screenCaptureAllowsOwner() async throws {
    let engine = try await makeProductionEngine()
    let decision = await evaluate(.screenCapture, engine: engine)
    guard case .allow = decision else {
      Issue.record("Expected .allow for screen.capture, got \(decision)")
      return
    }
  }

  @Test("the registered set is the one this test thinks it is")
  func registeredSetShape() {
    // Guard against the coverage loop silently iterating an empty list.
    let manifests = InitialCapabilitySet.manifests()
    #expect(manifests.count >= 40)
    #expect(ComputerUseSemanticIntent.allCases.count >= 10)
  }
}
