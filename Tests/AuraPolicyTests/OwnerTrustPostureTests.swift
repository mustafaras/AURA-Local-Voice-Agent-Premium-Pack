import AuraCore
import Foundation
import Testing

@testable import AuraPolicy

/// ADR-064 (PA-0 G0-2): `OwnerTrustPosture.isEnabled` must be the *only*
/// difference between the owner seed set and the pre-PA-0 seed set. These
/// tests build both branches through `DefaultPolicyGrants.grants(ownerTrustEnabled:)`
/// and diff them field by field, so a future edit that widens a grant
/// without going through the switch — or narrows one that the switch is
/// supposed to widen — fails here rather than in a live turn.
@Suite("OwnerTrustPosture (ADR-064)")
struct OwnerTrustPostureTests {
  /// The eight capabilities whose seeded requirement the posture governs
  /// (five `.always`, three `.forRiskTier(.mutation)` before PA-0).
  private static let governed: [(Capability, ConfirmationRequirement)] = [
    (.shellExec, .always),
    (.agentCodexRun, .always),
    (.agentClaudeRun, .always),
    (.agentCopilotRun, .always),
    (.agentOllamaCloudInference, .always),
    (.appTerminate, .forRiskTier(.mutation)),
    (.lifecycleLaunchAtLogin, .forRiskTier(.mutation)),
    (.computerUseRun, .forRiskTier(.mutation)),
  ]

  /// Everything about a grant except its minted `id` and `createdAt`.
  private struct Shape: Equatable {
    let capability: Capability
    let patterns: [ResourcePattern]
    let confirmationRequirement: ConfirmationRequirement
    let expiresAt: Date?
    let issuer: ActorID
    let subjectActor: ActorID?
    let purpose: String
    init(_ g: Grant) {
      capability = g.capability
      patterns = g.patterns
      confirmationRequirement = g.confirmationRequirement
      expiresAt = g.expiresAt
      issuer = g.issuer
      subjectActor = g.subjectActor
      purpose = g.purpose
    }
  }

  @Test("the production build has the owner posture enabled")
  func productionPostureEnabled() {
    // ADR-064 §1: this is the local, non-transferable posture. If this
    // assertion is ever changed, ADR-064's falsifiers must be re-read first.
    #expect(OwnerTrustPosture.isEnabled)
    #expect(
      DefaultPolicyGrants.all.map(Shape.init)
        == DefaultPolicyGrants.grants(ownerTrustEnabled: true).map(Shape.init))
  }

  @Test("with the posture enabled every seeded grant resolves to .none")
  func enabledPostureNeverChallenges() {
    for grant in DefaultPolicyGrants.grants(ownerTrustEnabled: true) {
      #expect(
        grant.confirmationRequirement == .none,
        "\(grant.capability.identifier) still carries \(grant.confirmationRequirement)")
    }
  }

  @Test("with the posture disabled the governed grants keep their pre-PA-0 requirement")
  func disabledPostureRestoresChallenges() {
    let legacy = DefaultPolicyGrants.grants(ownerTrustEnabled: false)
    for (capability, expected) in Self.governed {
      let grant = legacy.first { $0.capability == capability }
      #expect(grant != nil, "\(capability.identifier) missing from the legacy seed set")
      #expect(
        grant?.confirmationRequirement == expected,
        "\(capability.identifier) expected \(expected), got \(String(describing: grant?.confirmationRequirement))"
      )
    }
  }

  @Test("the switch is the only difference between the two seed sets")
  func switchIsTheOnlyDifference() {
    let enabled = DefaultPolicyGrants.grants(ownerTrustEnabled: true).map(Shape.init)
    let disabled = DefaultPolicyGrants.grants(ownerTrustEnabled: false).map(Shape.init)
    #expect(enabled.count == disabled.count)
    let governed = Set(Self.governed.map(\.0))
    for (a, b) in zip(enabled, disabled) {
      #expect(a.capability == b.capability)
      #expect(a.patterns == b.patterns, "\(a.capability.identifier) patterns differ")
      #expect(a.expiresAt == b.expiresAt)
      #expect(a.issuer == b.issuer)
      #expect(a.subjectActor == b.subjectActor)
      #expect(a.purpose == b.purpose)
      if governed.contains(a.capability) {
        #expect(a.confirmationRequirement == .none)
        #expect(b.confirmationRequirement != .none, "\(a.capability.identifier) not governed")
      } else {
        #expect(
          a.confirmationRequirement == b.confirmationRequirement,
          "\(a.capability.identifier) changed outside the switch")
      }
    }
  }

  @Test("the derived constants map the switch exactly")
  func derivedConstants() {
    #expect(DefaultPolicyGrants.ownerConfirmation(ownerTrustEnabled: true) == .none)
    #expect(DefaultPolicyGrants.ownerConfirmation(ownerTrustEnabled: false) == .always)
    #expect(DefaultPolicyGrants.ownerMutationConfirmation(ownerTrustEnabled: true) == .none)
    #expect(
      DefaultPolicyGrants.ownerMutationConfirmation(ownerTrustEnabled: false)
        == .forRiskTier(.mutation))
  }

  @Test("seeded grants still carry the reconcile marker under both postures")
  func seedMarkerPreserved() {
    for enabled in [true, false] {
      for grant in DefaultPolicyGrants.grants(ownerTrustEnabled: enabled) {
        #expect(grant.purpose == DefaultPolicyGrants.seedPurpose)
      }
    }
  }
}
