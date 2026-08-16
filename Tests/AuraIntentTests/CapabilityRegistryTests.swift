import AuraCore
import AuraIntent
import Foundation
import Testing

private func makeManifest(
  id: String = "test.capability",
  version: String = "1.0.0",
  requiredCapability: Capability = .intentConverse
) -> CapabilityManifest {
  CapabilityManifest(
    id: id, version: version,
    presentation: CapabilityPresentation(
      titleByLocale: [.english: "Test"], descriptionByLocale: [.english: "A test capability."]),
    inputSchemaDescription: "none", outputSchemaDescription: "none",
    owningAdapter: "test", requiredCapability: requiredCapability, isIdempotent: true,
    executionBudget: CapabilityExecutionBudget(
      timeoutSeconds: 1, supportsCancellation: false, isRetryable: true),
    confirmationRule: "none", verificationMethod: "none", rollbackStrategy: "none")
}

@Test
func registryFailsClosedForUnknownID() async {
  let registry = CapabilityRegistry()
  #expect(await registry.manifest(id: "does.not.exist", version: "1.0.0") == nil)
  #expect(await registry.resolveLatest(id: "does.not.exist") == nil)
}

@Test
func registryFailsClosedForKnownIDWrongVersion() async {
  let registry = CapabilityRegistry()
  await registry.register(makeManifest(), availability: .ready)
  #expect(await registry.manifest(id: "test.capability", version: "9.9.9") == nil)
}

@Test
func registryResolveLatestPicksHighestRegisteredVersion() async {
  let registry = CapabilityRegistry()
  await registry.register(makeManifest(version: "1.0.0"), availability: .ready)
  await registry.register(makeManifest(version: "1.2.0"), availability: .ready)
  await registry.register(makeManifest(version: "1.1.0"), availability: .ready)
  let latest = await registry.resolveLatest(id: "test.capability")
  #expect(latest?.version == "1.2.0")
}

@Test
func registryReplacingSameQualifiedIDOverwrites() async {
  let registry = CapabilityRegistry()
  await registry.register(makeManifest(requiredCapability: .intentConverse), availability: .ready)
  await registry.register(makeManifest(requiredCapability: .appActivate), availability: .ready)
  let manifest = await registry.manifest(id: "test.capability", version: "1.0.0")
  #expect(manifest?.requiredCapability == .appActivate)
}

@Test
func registryReachableManifestsExcludesDisabledAndDegraded() async {
  let registry = CapabilityRegistry()
  await registry.register(makeManifest(id: "ready.one"), availability: .ready)
  await registry.register(
    makeManifest(id: "degraded.one"), availability: .degraded(reason: "temporarily unavailable"))
  await registry.register(
    makeManifest(id: "disabled.one"), availability: .disabled(reason: "not implemented yet"))
  let reachable = await registry.reachableManifests()
  #expect(reachable.count == 1)
  #expect(reachable.first?.id == "ready.one")
}

@Test
func registryAllManifestsIncludesDisabledEntriesForHealthInspection() async {
  let registry = CapabilityRegistry()
  await registry.register(makeManifest(id: "ready.one"), availability: .ready)
  await registry.register(
    makeManifest(id: "disabled.one"), availability: .disabled(reason: "not implemented yet"))
  #expect(await registry.allManifests().count == 2)
}

@Test
func initialCapabilitySetRegistersEveryTargetManifest() async {
  let registry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: registry)
  #expect(await registry.allManifests().count == InitialCapabilitySet.manifests().count)
  // 10 from R3's initial set, plus SP-004's four filesystem/URL adapters.
  #expect(await registry.reachableManifests().count == 14)
}

@Test
func initialCapabilitySetRegistersR6VSCodeRoutesDisabledUntilLiveBridge() async {
  let registry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: registry)
  for id in [
    "vscode.editor_state", "vscode.workspace_status", "vscode.diagnostics",
    "vscode.run_task", "vscode.cancel_task", "vscode.run_tests",
    "vscode.cancel_tests", "vscode.terminal_sessions", "vscode.bridge_health",
  ] {
    guard
      case .disabled(let reason)? = await registry.availability(
        id: id, version: "1.0.0")
    else {
      Issue.record("expected \(id) to be registered disabled")
      continue
    }
    #expect(reason.contains("authenticated extension"))
  }
}

@Test
func initialCapabilitySetDisabledEntriesCarryTruthfulReasons() async {
  let registry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: registry)
  // Previously sampled `filesystem.open_file`, which SP-004 made `.ready`.
  // `browser.read` still has no packaged extension, so it is the current
  // example of a registered-but-unwired capability.
  guard
    case .disabled(let reason)? = await registry.availability(
      id: "browser.read", version: "1.0.0")
  else {
    Issue.record("expected browser.read to be registered disabled")
    return
  }
  #expect(!reason.isEmpty)
  #expect(!reason.lowercased().contains("todo"))
}

/// SP-004's completion gate: the four filesystem/URL capabilities are backed
/// by a real adapter and truthfully registered. Reachability here means the
/// direct `AuraKernel` call path, not NLU or UI — that remains SP-005's work,
/// so `OPEN-04` is not closed by this test passing.
@Test
func sp004FilesystemAndURLCapabilitiesAreReadyWithRealAdapters() async {
  let registry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: registry)
  for id in [
    "filesystem.open_file", "filesystem.open_folder", "filesystem.reveal", "url.open",
  ] {
    guard case .ready? = await registry.availability(id: id, version: "1.0.0") else {
      Issue.record("expected \(id) to be registered ready")
      continue
    }
    guard let manifest = await registry.resolveLatest(id: id) else {
      Issue.record("expected \(id) to resolve")
      continue
    }
    // A `.ready` capability must not still advertise a placeholder adapter or
    // verification method — that combination is exactly the false-readiness
    // this program forbids.
    #expect(manifest.owningAdapter.contains("FileSystemURLOpener"))
    #expect(!manifest.owningAdapter.lowercased().contains("not yet implemented"))
    #expect(!manifest.verificationMethod.lowercased().contains("not yet implemented"))
    #expect(manifest.verificationMethod.count > 40)
  }
}

@Test
func manifestPresentationFallsBackToEnglishForUnknownLocale() {
  let manifest = makeManifest()
  #expect(manifest.presentation.title(for: .turkish) == "Test")
}

@Test
func computerUseRunRegisteredDisabledUntilApproved() async {
  let registry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: registry)
  // `computerUse.run` is registered but truthfully `.disabled`: it is
  // implemented (DeterministicComputerUsePlanner) but not yet wired into a
  // live user path and requires an approved, live-validated beta app.
  guard
    case .disabled(let reason)? = await registry.availability(
      id: "computerUse.run", version: "1.0.0")
  else {
    Issue.record("expected computerUse.run to be registered disabled")
    return
  }
  #expect(!reason.isEmpty)
  #expect(!reason.lowercased().contains("todo"))
  // Adding a disabled manifest must not change the reachable count.
  // 10 from R3's initial set, plus SP-004's four filesystem/URL adapters.
  #expect(await registry.reachableManifests().count == 14)
}
