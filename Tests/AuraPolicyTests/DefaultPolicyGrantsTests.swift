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

  @Test("SP-006: filesystem/URL capabilities are allowed for in-scope targets")
  func filesystemAndURLCapabilitiesAllowed() async throws {
    let engine = try await makeProductionEngine()
    let inRoot = (DeclaredFileRoots.all[0] as NSString).appendingPathComponent("note.txt")
    let cases: [(Capability, PolicyTarget)] = [
      (.fileOpen, PolicyTarget(filePath: inRoot)),
      (.fileReveal, PolicyTarget(filePath: inRoot)),
      (.urlOpen, PolicyTarget(networkHost: "example.com", urlScheme: "https")),
    ]
    for (capability, target) in cases {
      let decision = await evaluate(capability, engine: engine, target: target)
      guard case .allow = decision else {
        Issue.record("Expected .allow for \(capability.identifier), got \(decision)")
        return
      }
    }
  }

  @Test("RISK-SP-006-DEFAULT-GRANT-BREADTH: a path outside every declared root is denied")
  func fileOutsideDeclaredRootsDenied() async throws {
    let engine = try await makeProductionEngine()
    // `/etc` is outside home and every temp root, so no seeded grant's
    // `.directory` pattern can match it. Before the grants were scoped this
    // returned .allow, and the adapter's empty `approvedRoots` did not
    // confine it either.
    for capability in [Capability.fileOpen, .fileReveal] {
      let decision = await evaluate(
        capability, engine: engine, target: PolicyTarget(filePath: "/etc/hosts"))
      guard case .deny = decision else {
        Issue.record("Expected .deny for \(capability.identifier) on /etc/hosts, got \(decision)")
        return
      }
    }
  }

  @Test("a file request carrying no path matches no scoped grant")
  func filesystemWithoutTargetDenied() async throws {
    let engine = try await makeProductionEngine()
    let decision = await evaluate(.fileOpen, engine: engine, target: .empty)
    guard case .deny = decision else {
      Issue.record("Expected .deny for fileOpen with an empty target, got \(decision)")
      return
    }
  }

  @Test("url.open is scoped to the adapter's scheme allowlist")
  func urlSchemeScoping() async throws {
    let engine = try await makeProductionEngine()
    for scheme in DeclaredFileRoots.allowedURLSchemes {
      let decision = await evaluate(
        .urlOpen, engine: engine, target: PolicyTarget(urlScheme: scheme))
      guard case .allow = decision else {
        Issue.record("Expected .allow for url.open scheme \(scheme), got \(decision)")
        return
      }
    }
    // `file:`, `ftp:`, and `javascript:` are outside the allowlist.
    for scheme in ["file", "ftp", "javascript"] {
      let decision = await evaluate(
        .urlOpen, engine: engine, target: PolicyTarget(urlScheme: scheme))
      guard case .deny = decision else {
        Issue.record("Expected .deny for url.open scheme \(scheme), got \(decision)")
        return
      }
    }
    // A target with no scheme is not a URL open at all.
    let noScheme = await evaluate(
      .urlOpen, engine: engine, target: PolicyTarget(networkHost: "example.com"))
    guard case .deny = noScheme else {
      Issue.record("Expected .deny for url.open with no scheme, got \(noScheme)")
      return
    }
  }

  @Test("mailto has no host, so scheme scoping must still authorize it")
  func mailtoStillAllowed() async throws {
    let engine = try await makeProductionEngine()
    // Regression guard for the reason `.network(host:port:)` was rejected as
    // the scoping mechanism: a mailto URL's host is nil.
    let decision = await evaluate(
      .urlOpen, engine: engine, target: PolicyTarget(networkHost: nil, urlScheme: "mailto"))
    guard case .allow = decision else {
      Issue.record("Expected .allow for mailto, got \(decision)")
      return
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

  @Test("filesystem grants are root-scoped, never .any")
  func filesystemGrantsAreScoped() {
    let fileGrants = DefaultPolicyGrants.all.filter {
      $0.capability == .fileOpen || $0.capability == .fileReveal
    }
    #expect(!fileGrants.isEmpty)
    for grant in fileGrants {
      #expect(!grant.patterns.contains(.any))
      // Exactly one `.directory` pattern per grant: a grant matches only when
      // every one of its patterns matches, so two roots in one grant would
      // require a path to be under both at once.
      #expect(grant.patterns.count == 1)
      guard case .directory(let root, recursive: true) = grant.patterns[0] else {
        Issue.record("Expected a recursive .directory pattern, got \(grant.patterns)")
        return
      }
      #expect(DeclaredFileRoots.all.contains(root))
    }
    // Every declared root is covered for both capabilities.
    for capability in [Capability.fileOpen, .fileReveal] {
      let roots = fileGrants.filter { $0.capability == capability }.compactMap { grant -> String? in
        guard case .directory(let root, _) = grant.patterns[0] else { return nil }
        return root
      }
      #expect(Set(roots) == Set(DeclaredFileRoots.all))
    }
  }

  @Test("url.open grant is scheme-scoped, never .any")
  func urlGrantIsScoped() {
    let urlGrants = DefaultPolicyGrants.all.filter { $0.capability == .urlOpen }
    #expect(urlGrants.count == 1)
    guard case .urlScheme(let allowed) = urlGrants[0].patterns[0] else {
      Issue.record("Expected a .urlScheme pattern, got \(urlGrants[0].patterns)")
      return
    }
    #expect(Set(allowed) == Set(DeclaredFileRoots.allowedURLSchemes))
  }

  @Test("no seeded grant uses an unrestricted .any pattern on a targetable capability")
  func noBroadPatternsOnTargetableCapabilities() {
    for grant in DefaultPolicyGrants.all
    where [Capability.fileOpen, .fileReveal, .urlOpen].contains(grant.capability) {
      #expect(!grant.patterns.contains(.any))
    }
  }

  // MARK: - Seed reconciliation (the live-run finding)

  /// A live SP-006 follow-up run found 895 persisted grants, 30 of them
  /// pre-scoping `.any` grants for the filesystem/URL capabilities. Because
  /// `matchingGrant` returns the first match, those legacy grants kept
  /// authorizing paths the scoped grants were written to refuse — the scoping
  /// was correct in tests and inert in the field.
  private func makeEngineWithLegacyBroadGrants() async throws -> PolicyEngine {
    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AuraPolicyTests", category: "seed-reconcile"))
    let engine = try await PolicyEngine(
      configuration: PolicyConfiguration(), eventBus: bus, store: nil)
    // Exactly the pre-marker shape: no purpose, patterns [.any].
    for capability in [Capability.fileOpen, .fileReveal, .urlOpen, .appActivate] {
      try await engine.issueGrant(
        Grant(capability: capability, patterns: [.any], confirmationRequirement: .none))
    }
    return engine
  }

  @Test("reconciliation prunes legacy broad grants so scoping actually takes effect")
  func reconcilePrunesLegacyBroadGrants() async throws {
    let engine = try await makeEngineWithLegacyBroadGrants()
    // Before reconciliation the legacy grant authorizes an out-of-root path.
    let before = await evaluate(
      .fileOpen, engine: engine, target: PolicyTarget(filePath: "/etc/hosts"))
    guard case .allow = before else {
      Issue.record("expected the legacy broad grant to allow /etc/hosts, got \(before)")
      return
    }

    let pruned = try await engine.reconcileSeededGrants(
      DefaultPolicyGrants.all, marker: DefaultPolicyGrants.seedPurpose)
    #expect(pruned == 4)

    // After reconciliation the same request is denied.
    let after = await evaluate(
      .fileOpen, engine: engine, target: PolicyTarget(filePath: "/etc/hosts"))
    guard case .deny = after else {
      Issue.record("expected .deny for /etc/hosts after reconciliation, got \(after)")
      return
    }
    // …and an in-root path still works.
    let inRoot = (DeclaredFileRoots.all[0] as NSString).appendingPathComponent("note.txt")
    let allowed = await evaluate(
      .fileOpen, engine: engine, target: PolicyTarget(filePath: inRoot))
    guard case .allow = allowed else {
      Issue.record("expected .allow for an in-root path, got \(allowed)")
      return
    }
  }

  @Test("reconciliation is idempotent — repeated seeding cannot grow the grant set")
  func reconcileIsIdempotent() async throws {
    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AuraPolicyTests", category: "seed-idempotent"))
    let engine = try await PolicyEngine(
      configuration: PolicyConfiguration(), eventBus: bus, store: nil)
    var counts: [Int] = []
    for _ in 0..<3 {
      try await engine.reconcileSeededGrants(
        DefaultPolicyGrants.all, marker: DefaultPolicyGrants.seedPurpose)
      counts.append(await engine.grants.count)
    }
    // Three launches must leave exactly one copy of the seeded set — the old
    // loop produced three.
    #expect(counts == [DefaultPolicyGrants.all.count, DefaultPolicyGrants.all.count,
      DefaultPolicyGrants.all.count])
  }

  @Test("reconciliation leaves grants outside the seed signature untouched")
  func reconcilePreservesOtherGrants() async throws {
    let bus = AuraEventBus(
      logger: AuraLogger(subsystem: "AuraPolicyTests", category: "seed-preserve"))
    let engine = try await PolicyEngine(
      configuration: PolicyConfiguration(), eventBus: bus, store: nil)
    // A narrow, purposeful grant from some other path must survive: only the
    // unmarked `.any` legacy shape and marked seeds are pruned.
    let keeper = Grant(
      capability: .fileOpen, patterns: [.directory("/Users/someone/Documents", recursive: true)],
      confirmationRequirement: .none, purpose: "issued by a user action")
    try await engine.issueGrant(keeper)
    try await engine.reconcileSeededGrants(
      DefaultPolicyGrants.all, marker: DefaultPolicyGrants.seedPurpose)
    let surviving = await engine.grants
    #expect(surviving.contains { $0.id == keeper.id })
  }

  @Test("every seeded grant carries the marker, so none can escape reconciliation")
  func allSeededGrantsAreMarked() {
    #expect(DefaultPolicyGrants.all.allSatisfy { $0.purpose == DefaultPolicyGrants.seedPurpose })
    #expect(!DefaultPolicyGrants.all.isEmpty)
  }

  @Test("grant list contains exactly the intended capabilities")
  func grantInventoryIsExact() {
    let identifiers = DefaultPolicyGrants.all.map { $0.capability.identifier }
    // Filesystem capabilities intentionally appear once per declared root, so
    // identifiers are no longer unique; the capability *set* still is.
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
