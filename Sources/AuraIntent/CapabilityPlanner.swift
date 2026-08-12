import AuraCore
import CryptoKit
import Foundation

/// One validated step of a `Plan` — `04_R3_CAPABILITY_REGISTRY_AND_PLANNER
/// .prompt.md`'s "Planner" section, field for field. Risk/confirmation are
/// always recomputed from the registry at plan time, never trusted from a
/// caller-supplied value, mirroring `ToolRouter.resolvePolicy`'s existing
/// "policy is authoritative" discipline.
public struct PlanStep: Sendable, Equatable {
  public let capabilityID: String
  public let capabilityVersion: String
  public let validatedArguments: [String: String]
  public let expectedPreconditions: [String]
  public let expectedPostconditions: [String]
  public let riskTier: PermissionRiskTier
  public let requiredCapability: Capability
  public let dependsOnStepIndices: [Int]
  public let timeoutSeconds: Double
  public let verificationMethod: String
  public let rollbackStrategy: String

  public var qualifiedCapabilityID: String { "\(capabilityID)@\(capabilityVersion)" }
}

/// Caller-supplied step request validated by `CapabilityPlanner` before it is
/// materialized into an immutable `PlanStep`.
public struct PlanStepRequest: Sendable, Equatable {
  public let capabilityID: String
  public let arguments: [String: String]
  public let requiredArgumentNames: [String]
  public let dependsOnStepIndices: [Int]

  public init(
    capabilityID: String,
    arguments: [String: String],
    requiredArgumentNames: [String],
    dependsOnStepIndices: [Int]
  ) {
    self.capabilityID = capabilityID
    self.arguments = arguments
    self.requiredArgumentNames = requiredArgumentNames
    self.dependsOnStepIndices = dependsOnStepIndices
  }
}

/// An immutable, hash-identified sequence of `PlanStep`s.
/// `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`: "Plans must be
/// immutable after confirmation. Replanning creates a new plan identity" —
/// `fingerprint` is that identity; any change to the steps (including
/// argument values) produces a different plan, never a mutation in place.
public struct Plan: Sendable, Equatable {
  public let id: UUID
  public let steps: [PlanStep]
  public let fingerprint: String

  fileprivate init(id: UUID = UUID(), steps: [PlanStep]) {
    self.id = id
    self.steps = steps
    self.fingerprint = Plan.computeFingerprint(steps: steps)
  }

  fileprivate static func computeFingerprint(steps: [PlanStep]) -> String {
    struct StepFingerprint: Encodable {
      let capabilityID: String
      let capabilityVersion: String
      let arguments: [String: String]
      let dependsOn: [Int]
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let fingerprints = steps.map {
      StepFingerprint(
        capabilityID: $0.capabilityID, capabilityVersion: $0.capabilityVersion,
        arguments: $0.validatedArguments, dependsOn: $0.dependsOnStepIndices)
    }
    guard let data = try? encoder.encode(fingerprints) else {
      return SHA256.hash(data: Data()).map { String(format: "%02x", $0) }.joined()
    }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}

/// The bounded set of outcomes the planner can produce —
/// `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`'s "Planner" section.
public enum PlanResult: Sendable, Equatable {
  case directAnswer(text: String)
  case clarification(question: String)
  case singleCapabilityCall(Plan)
  case multiStepPlan(Plan)
  case delegatedTask(Plan)
  case refusal(reason: String)
}

/// Reasons a proposed capability call was rejected before ever reaching a
/// `Plan` — covers `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`'s
/// required "unknown capability IDs," "invalid arguments," "missing
/// permissions/dependencies," and "unavailable capability health" test
/// cases in one typed surface, rather than a bare `nil`.
public enum PlanValidationFailure: Error, Sendable, Equatable {
  case unknownCapability(id: String, version: String)
  case capabilityUnavailable(id: String, reason: String)
  case missingRequiredArgument(capabilityID: String, name: String)
  case planTooLarge(stepCount: Int, maxSteps: Int)
  case dependencyCycle
  case invalidDependencyIndex(stepIndex: Int, dependsOn: Int)
}

/// A bounded typed planner: `CapabilityRegistry` is the only source of
/// truth for what a step is allowed to look like, so a caller (including a
/// model-proposed plan) can never invent a capability, and every produced
/// `Plan` carries an immutable fingerprint used both for confirmation
/// binding (mirrors `PolicyPlanHasher`) and for detecting stale replans.
public actor CapabilityPlanner {
  private let registry: CapabilityRegistry
  public let maxStepsPerPlan: Int

  public init(registry: CapabilityRegistry, maxStepsPerPlan: Int = 5) {
    self.registry = registry
    self.maxStepsPerPlan = maxStepsPerPlan
  }

  /// Validate and build a single step against the registry's latest
  /// registered version of `capabilityID`. Every required-argument key
  /// listed in `requiredArgumentNames` must be present and non-empty in
  /// `arguments`, or the step is rejected — this is the seam
  /// `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`'s "model-proposed
  /// unknown/out-of-schema tools" test exercises: a model can propose
  /// anything, but only a manifest-validated step ever becomes a `PlanStep`.
  public func validateStep(
    capabilityID: String,
    arguments: [String: String],
    requiredArgumentNames: [String] = [],
    dependsOnStepIndices: [Int] = []
  ) async -> Result<PlanStep, PlanValidationFailure> {
    guard let manifest = await registry.resolveLatest(id: capabilityID) else {
      return .failure(.unknownCapability(id: capabilityID, version: "latest"))
    }
    if let availability = await registry.availability(qualifiedID: manifest.qualifiedID) {
      switch availability {
      case .ready:
        break
      case .degraded(let reason), .disabled(let reason):
        return .failure(.capabilityUnavailable(id: capabilityID, reason: reason))
      }
    }
    for name in requiredArgumentNames {
      guard let value = arguments[name], !value.isEmpty else {
        return .failure(.missingRequiredArgument(capabilityID: capabilityID, name: name))
      }
    }
    return .success(
      PlanStep(
        capabilityID: manifest.id,
        capabilityVersion: manifest.version,
        validatedArguments: arguments,
        expectedPreconditions: [],
        expectedPostconditions: [],
        riskTier: manifest.requiredCapability.riskTier,
        requiredCapability: manifest.requiredCapability,
        dependsOnStepIndices: dependsOnStepIndices,
        timeoutSeconds: manifest.executionBudget.timeoutSeconds,
        verificationMethod: manifest.verificationMethod,
        rollbackStrategy: manifest.rollbackStrategy))
  }

  /// Build and validate a bounded multi-step plan. Rejects (does not
  /// silently truncate) plans exceeding `maxStepsPerPlan`, dependency
  /// cycles, and out-of-range dependency indices — every failure mode
  /// `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`'s "plan cycle and
  /// budget rejection" test requires.
  public func buildPlan(
    steps stepRequests: [PlanStepRequest]
  ) async -> Result<Plan, PlanValidationFailure> {
    guard stepRequests.count <= maxStepsPerPlan else {
      return .failure(.planTooLarge(stepCount: stepRequests.count, maxSteps: maxStepsPerPlan))
    }
    var steps: [PlanStep] = []
    for (index, request) in stepRequests.enumerated() {
      for dependsOn in request.dependsOnStepIndices {
        guard dependsOn >= 0, dependsOn < index else {
          // A dependency must point strictly backward in the sequence —
          // this simultaneously rejects out-of-range indices and any
          // cycle, since a cycle requires a forward or self reference.
          if dependsOn == index || dependsOn >= stepRequests.count {
            return .failure(.dependencyCycle)
          }
          return .failure(.invalidDependencyIndex(stepIndex: index, dependsOn: dependsOn))
        }
      }
      switch await validateStep(
        capabilityID: request.capabilityID, arguments: request.arguments,
        requiredArgumentNames: request.requiredArgumentNames,
        dependsOnStepIndices: request.dependsOnStepIndices)
      {
      case .success(let step): steps.append(step)
      case .failure(let failure): return .failure(failure)
      }
    }
    return .success(Plan(steps: steps))
  }

  /// Convenience for the common single-capability case.
  public func planSingleCall(
    capabilityID: String,
    arguments: [String: String],
    requiredArgumentNames: [String] = []
  ) async -> Result<Plan, PlanValidationFailure> {
    await buildPlan(steps: [
      PlanStepRequest(
        capabilityID: capabilityID, arguments: arguments,
        requiredArgumentNames: requiredArgumentNames, dependsOnStepIndices: []
      )
    ])
  }
}
