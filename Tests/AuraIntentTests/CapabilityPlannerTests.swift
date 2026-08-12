import AuraCore
import AuraIntent
import Foundation
import Testing

private func makeRegistry() async -> CapabilityRegistry {
  let registry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: registry)
  return registry
}

// MARK: - Single-step validation

@Test
func plannerRejectsUnknownCapabilityID() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let result = await planner.validateStep(capabilityID: "not.a.real.capability", arguments: [:])
  guard case .failure(.unknownCapability(let id, _)) = result else {
    Issue.record("expected unknownCapability failure, got \(result)")
    return
  }
  #expect(id == "not.a.real.capability")
}

@Test
func plannerRejectsModelProposedOutOfSchemaCapability() async {
  // Simulates a model proposing a capability it invented rather than one
  // pulled from the registry — must be rejected, never silently accepted.
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let result = await planner.validateStep(
    capabilityID: "agent.rm_rf_everything", arguments: ["path": "/"])
  #expect(result.isFailure)
}

@Test
func plannerRejectsDisabledCapability() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let result = await planner.validateStep(
    capabilityID: "url.open", arguments: ["url": "https://example.com"])
  guard case .failure(.capabilityUnavailable(let id, let reason)) = result else {
    Issue.record("expected capabilityUnavailable failure, got \(result)")
    return
  }
  #expect(id == "url.open")
  #expect(!reason.isEmpty)
}

@Test
func plannerRejectsMissingRequiredArgument() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let result = await planner.validateStep(
    capabilityID: "app.activate", arguments: [:], requiredArgumentNames: ["bundleIdentifier"])
  guard case .failure(.missingRequiredArgument(_, let name)) = result else {
    Issue.record("expected missingRequiredArgument failure, got \(result)")
    return
  }
  #expect(name == "bundleIdentifier")
}

@Test
func plannerRejectsEmptyStringRequiredArgumentSameAsMissing() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let result = await planner.validateStep(
    capabilityID: "app.activate", arguments: ["bundleIdentifier": ""],
    requiredArgumentNames: ["bundleIdentifier"])
  #expect(result.isFailure)
}

@Test
func plannerAcceptsValidSingleStepAndRecomputesRiskFromRegistryNotCaller() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let result = await planner.validateStep(
    capabilityID: "app.quit", arguments: ["bundleIdentifier": "com.example.app"],
    requiredArgumentNames: ["bundleIdentifier"])
  guard case .success(let step) = result else {
    Issue.record("expected success, got \(result)")
    return
  }
  // app.quit's manifest declares .mutation risk; a caller cannot lower or
  // raise this by any argument it supplies — the planner never trusts a
  // caller-declared risk tier, only the registry's.
  #expect(step.riskTier == .mutation)
  #expect(step.requiredCapability == .appTerminate)
}

// MARK: - Multi-step plans

@Test
func plannerBuildsMultiStepPlanWithDependencyOrdering() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let result = await planner.buildPlan(steps: [
    PlanStepRequest(
      capabilityID: "app.discover", arguments: [:], requiredArgumentNames: [],
      dependsOnStepIndices: []
    ),
    PlanStepRequest(
      capabilityID: "app.activate", arguments: ["bundleIdentifier": "com.example.app"],
      requiredArgumentNames: ["bundleIdentifier"], dependsOnStepIndices: [0]
    ),
  ])
  guard case .success(let plan) = result else {
    Issue.record("expected success, got \(result)")
    return
  }
  #expect(plan.steps.count == 2)
  #expect(plan.steps[1].dependsOnStepIndices == [0])
}

@Test
func plannerRejectsPlanExceedingMaxSteps() async {
  let planner = CapabilityPlanner(registry: await makeRegistry(), maxStepsPerPlan: 2)
  let result = await planner.buildPlan(steps: [
    PlanStepRequest(
      capabilityID: "app.discover", arguments: [:], requiredArgumentNames: [],
      dependsOnStepIndices: []
    ),
    PlanStepRequest(
      capabilityID: "app.discover", arguments: [:], requiredArgumentNames: [],
      dependsOnStepIndices: []
    ),
    PlanStepRequest(
      capabilityID: "app.discover", arguments: [:], requiredArgumentNames: [],
      dependsOnStepIndices: []
    ),
  ])
  guard case .failure(.planTooLarge(let stepCount, let maxSteps)) = result else {
    Issue.record("expected planTooLarge failure, got \(result)")
    return
  }
  #expect(stepCount == 3)
  #expect(maxSteps == 2)
}

@Test
func plannerRejectsForwardDependencyAsCycle() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let result = await planner.buildPlan(steps: [
    PlanStepRequest(
      capabilityID: "app.discover", arguments: [:], requiredArgumentNames: [],
      dependsOnStepIndices: [1]
    ),
    PlanStepRequest(
      capabilityID: "app.discover", arguments: [:], requiredArgumentNames: [],
      dependsOnStepIndices: []
    ),
  ])
  #expect(result.isFailure)
}

@Test
func plannerRejectsSelfDependencyAsCycle() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let request = PlanStepRequest(
    capabilityID: "app.discover", arguments: [:], requiredArgumentNames: [],
    dependsOnStepIndices: [0])
  let result = await planner.buildPlan(steps: [request])
  guard case .failure(.dependencyCycle) = result else {
    Issue.record("expected dependencyCycle failure, got \(result)")
    return
  }
}

// MARK: - Plan fingerprint immutability

@Test
func planFingerprintChangesWithDifferentArguments() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let resultA = await planner.planSingleCall(
    capabilityID: "app.activate", arguments: ["bundleIdentifier": "com.example.a"],
    requiredArgumentNames: ["bundleIdentifier"])
  let resultB = await planner.planSingleCall(
    capabilityID: "app.activate", arguments: ["bundleIdentifier": "com.example.b"],
    requiredArgumentNames: ["bundleIdentifier"])
  guard case .success(let planA) = resultA, case .success(let planB) = resultB else {
    Issue.record("expected both plans to succeed")
    return
  }
  #expect(planA.fingerprint != planB.fingerprint)
  #expect(planA.id != planB.id)
}

@Test
func planFingerprintIsStableForIdenticalSteps() async {
  let planner = CapabilityPlanner(registry: await makeRegistry())
  let resultA = await planner.planSingleCall(
    capabilityID: "app.activate", arguments: ["bundleIdentifier": "com.example.a"],
    requiredArgumentNames: ["bundleIdentifier"])
  let resultB = await planner.planSingleCall(
    capabilityID: "app.activate", arguments: ["bundleIdentifier": "com.example.a"],
    requiredArgumentNames: ["bundleIdentifier"])
  guard case .success(let planA) = resultA, case .success(let planB) = resultB else {
    Issue.record("expected both plans to succeed")
    return
  }
  // Same steps, different plan identity (a fresh UUID each time — "replanning
  // creates a new plan identity") but the *fingerprint* — the immutability
  // and confirmation-binding key — is content-derived and must match.
  #expect(planA.fingerprint == planB.fingerprint)
  #expect(planA.id != planB.id)
}

extension Result {
  fileprivate var isFailure: Bool {
    if case .failure = self { return true }
    return false
  }
}
