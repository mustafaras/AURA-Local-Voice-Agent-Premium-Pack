import AuraCore
import AuraContext
import Foundation
import Testing

private func makeCandidate(
  description: String,
  capability: Capability? = nil,
  authority: ContextAuthority = .userStated,
  confidence: Double = 1.0,
  observedAt: Date = Date(),
  hasDirectEvidence: Bool = true,
  scopeMatch: Bool = true
) -> ReferenceCandidate {
  ReferenceCandidate(
    sourceID: .memoryRecord(recordID: UUID()), description: description, capability: capability,
    authority: authority, confidence: confidence, observedAt: observedAt,
    hasDirectEvidence: hasDirectEvidence, scopeMatch: scopeMatch)
}

// MARK: - Baseline behavior

@Test
func resolveWithNoCandidatesReturnsNone() {
  let resolver = ReferenceResolver()
  let resolution = resolver.resolve(reference: "it", candidates: [])
  #expect(resolution == .none)
}

@Test
func resolveSingleClearDestructiveCandidateWithStrongEvidenceResolves() {
  let resolver = ReferenceResolver()
  let candidate = makeCandidate(
    description: "~/Desktop/draft.txt", capability: .fileDelete, authority: .userStated,
    confidence: 0.95, hasDirectEvidence: true, scopeMatch: true)

  let resolution = resolver.resolve(reference: "delete it", candidates: [candidate])

  guard case .resolved(let resolved) = resolution else {
    Issue.record("expected resolved, got \(resolution)")
    return
  }
  #expect(resolved.description == "~/Desktop/draft.txt")
}

@Test
func resolveLowRiskCandidateWithWeakEvidenceStillResolves() {
  let resolver = ReferenceResolver()
  // Reversible tier, inferred authority, low confidence: acceptable to
  // auto-resolve because there is nothing destructive at stake.
  let candidate = makeCandidate(
    description: "Notes app", capability: .appActivate, authority: .inferred, confidence: 0.3,
    hasDirectEvidence: false, scopeMatch: false)

  let resolution = resolver.resolve(reference: "open it", candidates: [candidate])

  guard case .resolved = resolution else {
    Issue.record("expected resolved for a low-risk candidate, got \(resolution)")
    return
  }
}

// MARK: - Adversarial: never resolve destructive on weak evidence

@Test
func resolveDestructiveCandidateWithInferredLowConfidenceEvidenceBlocks() {
  let resolver = ReferenceResolver()
  let candidate = makeCandidate(
    description: "~/Desktop/entire-project", capability: .fileDelete, authority: .inferred,
    confidence: 0.5, hasDirectEvidence: false, scopeMatch: true)

  let resolution = resolver.resolve(reference: "delete it", candidates: [candidate])

  guard case .blockedWeakEvidence(let blocked) = resolution else {
    Issue.record("expected blockedWeakEvidence, got \(resolution)")
    return
  }
  #expect(blocked.description == "~/Desktop/entire-project")
}

@Test
func resolveMutationTierCandidateWithWeakEvidenceAlsoBlocks() {
  let resolver = ReferenceResolver()
  let candidate = makeCandidate(
    description: "~/Desktop/report.docx", capability: .fileWrite, authority: .observed,
    confidence: 0.5, hasDirectEvidence: true, scopeMatch: true)

  let resolution = resolver.resolve(reference: "overwrite it", candidates: [candidate])

  guard case .blockedWeakEvidence = resolution else {
    Issue.record("expected blockedWeakEvidence for a mutation-tier weak candidate, got \(resolution)")
    return
  }
}

@Test
func resolveOutOfScopeDestructiveCandidateBlocksEvenWithHighConfidence() {
  let resolver = ReferenceResolver()
  // High confidence and direct evidence, but scoped to a different
  // task/session than the current request: scope mismatch alone must block
  // a destructive resolution.
  let candidate = makeCandidate(
    description: "~/other-project/build", capability: .fileDelete, authority: .userStated,
    confidence: 0.99, hasDirectEvidence: true, scopeMatch: false)

  let resolution = resolver.resolve(reference: "delete it", candidates: [candidate])

  guard case .blockedWeakEvidence = resolution else {
    Issue.record("expected blockedWeakEvidence for an out-of-scope candidate, got \(resolution)")
    return
  }
}

@Test
func resolveAmbiguousDestructiveCandidatesNeverAutoResolve() {
  let resolver = ReferenceResolver()
  let now = Date()
  let candidateA = makeCandidate(
    description: "~/Desktop/report-v1.docx", capability: .fileDelete, authority: .userStated,
    confidence: 0.9, observedAt: now, hasDirectEvidence: true, scopeMatch: true)
  let candidateB = makeCandidate(
    description: "~/Desktop/report-v2.docx", capability: .fileDelete, authority: .userStated,
    confidence: 0.9, observedAt: now, hasDirectEvidence: true, scopeMatch: true)

  let resolution = resolver.resolve(reference: "delete it", candidates: [candidateA, candidateB])

  guard case .ambiguous(let candidates) = resolution else {
    Issue.record("expected ambiguous, got \(resolution)")
    return
  }
  #expect(candidates.count == 2)
}

@Test
func resolveTiedStrongCandidatesForDestructiveActionStaysAmbiguous() {
  var configuration = ContextConfiguration()
  configuration.referenceSeparationMargin = 0.2
  let resolver = ReferenceResolver(configuration: configuration)
  let now = Date()
  // Both candidates are individually strong enough to pass the weak-evidence
  // gate, but they are too close together to call a clear winner.
  let candidateA = makeCandidate(
    description: "~/Desktop/invoice-january.pdf", capability: .fileDelete, authority: .userStated,
    confidence: 0.95, observedAt: now, hasDirectEvidence: true, scopeMatch: true)
  let candidateB = makeCandidate(
    description: "~/Desktop/invoice-february.pdf", capability: .fileDelete, authority: .userStated,
    confidence: 0.9, observedAt: now.addingTimeInterval(-1), hasDirectEvidence: true,
    scopeMatch: true)

  let resolution = resolver.resolve(reference: "delete it", candidates: [candidateA, candidateB])

  guard case .ambiguous = resolution else {
    Issue.record("expected ambiguous for two closely-scored strong candidates, got \(resolution)")
    return
  }
}

// MARK: - Adversarial injection

@Test
func recentLowConfidenceInjectedCandidateCannotSilentlyWinADestructiveResolution() {
  let resolver = ReferenceResolver()
  let now = Date()
  // A legitimate, well-evidenced but slightly older destructive target...
  let legitimate = makeCandidate(
    description: "~/Desktop/old-draft.txt", capability: .fileDelete, authority: .userStated,
    confidence: 0.95, observedAt: now.addingTimeInterval(-120), hasDirectEvidence: true,
    scopeMatch: true)
  // ...versus an "injected" decoy that is very recent (maximal recency
  // score) but has no direct evidence, inferred authority, and low
  // confidence — e.g. a hostile prompt-injected mention trying to redirect
  // "it" toward a different destructive target purely by being freshest.
  let injectedDecoy = makeCandidate(
    description: "~/Desktop/entire-home-folder", capability: .fileDelete, authority: .inferred,
    confidence: 0.35, observedAt: now, hasDirectEvidence: false, scopeMatch: true)

  let resolution = resolver.resolve(
    reference: "delete it", candidates: [legitimate, injectedDecoy], referenceDate: now)

  // Whichever candidate the raw ranking prefers, the outcome must never be a
  // silent `.resolved` of a destructive action off the back of the weak
  // decoy: either the legitimate target wins outright, or an ambiguous/
  // weak-evidence guard fires — never a resolution to the decoy.
  switch resolution {
  case .resolved(let candidate):
    #expect(candidate.description == legitimate.description)
  case .blockedWeakEvidence(let candidate):
    #expect(candidate.description == injectedDecoy.description)
  case .ambiguous:
    break
  case .none:
    Issue.record("expected a decision, got .none")
  }
}

@Test
func injectedCandidateAloneWithoutCompetitionIsBlockedNotResolved() {
  let resolver = ReferenceResolver()
  // No legitimate candidate at all — only the weak, inferred, recency-boosted
  // decoy. Even unopposed, it must not resolve.
  let injectedDecoy = makeCandidate(
    description: "~/Desktop/entire-home-folder", capability: .fileDelete, authority: .inferred,
    confidence: 0.35, hasDirectEvidence: false, scopeMatch: true)

  let resolution = resolver.resolve(reference: "delete it", candidates: [injectedDecoy])

  guard case .blockedWeakEvidence = resolution else {
    Issue.record("expected blockedWeakEvidence, got \(resolution)")
    return
  }
}
