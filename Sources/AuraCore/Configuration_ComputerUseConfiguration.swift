import Foundation

/// Configuration for `ComputerUseControlLoop` (Phase 18) — iteration and
/// plan-size bounds, no-progress detection sensitivity, and action rate
/// limiting. Confirmation requirements for destructive intents are
/// deliberately *not* configurable here — see
/// `ComputerUseSemanticIntent.mandatoryConfirmationIntents`, a fixed
/// constant no configuration can relax.
public struct ComputerUseConfiguration: Codable, Sendable, Equatable {
  /// Hard ceiling on observe-plan-policy-act-verify iterations per session.
  public var maxIterations: Int

  /// Hard ceiling on action steps within a single proposed plan — "one
  /// bounded action or a short atomic sequence." A plan exceeding this is
  /// rejected outright, never silently truncated.
  public var maxStepsPerPlan: Int

  /// Consecutive iterations with no observable change (identical content
  /// hash) before the loop escalates to `.noProgress` instead of continuing
  /// indefinitely.
  public var noProgressIterationThreshold: Int

  /// Minimum seconds required between two consecutive executed action
  /// steps — bounds the action rate against the approved target.
  public var minActionIntervalSeconds: Double

  public init(
    maxIterations: Int = 25,
    maxStepsPerPlan: Int = 5,
    noProgressIterationThreshold: Int = 3,
    minActionIntervalSeconds: Double = 0.2
  ) {
    self.maxIterations = maxIterations
    self.maxStepsPerPlan = maxStepsPerPlan
    self.noProgressIterationThreshold = noProgressIterationThreshold
    self.minActionIntervalSeconds = minActionIntervalSeconds
  }

  public func validate() throws(AuraError) {
    guard maxIterations > 0 else {
      throw AuraError.invalidConfiguration("computerUse maxIterations must be positive")
    }
    guard maxStepsPerPlan > 0 else {
      throw AuraError.invalidConfiguration("computerUse maxStepsPerPlan must be positive")
    }
    guard noProgressIterationThreshold > 0 else {
      throw AuraError.invalidConfiguration(
        "computerUse noProgressIterationThreshold must be positive")
    }
    guard minActionIntervalSeconds >= 0 else {
      throw AuraError.invalidConfiguration(
        "computerUse minActionIntervalSeconds must not be negative")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> ComputerUseConfiguration {
    let defaults = ComputerUseConfiguration()
    return ComputerUseConfiguration(
      maxIterations: self.maxIterations <= 0 ? defaults.maxIterations : self.maxIterations,
      maxStepsPerPlan: self.maxStepsPerPlan <= 0
        ? defaults.maxStepsPerPlan : self.maxStepsPerPlan,
      noProgressIterationThreshold: self.noProgressIterationThreshold <= 0
        ? defaults.noProgressIterationThreshold : self.noProgressIterationThreshold,
      minActionIntervalSeconds: self.minActionIntervalSeconds < 0
        ? defaults.minActionIntervalSeconds : self.minActionIntervalSeconds
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = ComputerUseConfiguration()
    maxIterations =
      try container.decodeIfPresent(Int.self, forKey: .maxIterations) ?? defaults.maxIterations
    maxStepsPerPlan =
      try container.decodeIfPresent(Int.self, forKey: .maxStepsPerPlan)
      ?? defaults.maxStepsPerPlan
    noProgressIterationThreshold =
      try container.decodeIfPresent(Int.self, forKey: .noProgressIterationThreshold)
      ?? defaults.noProgressIterationThreshold
    minActionIntervalSeconds =
      try container.decodeIfPresent(Double.self, forKey: .minActionIntervalSeconds)
      ?? defaults.minActionIntervalSeconds
  }
}
