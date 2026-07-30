import Foundation

public struct FeatureFlagDefinition: Codable, Sendable, Equatable {
  public let key: String
  public let owner: String
  public let purpose: String
  public var expiresAt: Date
  public let defaultEnabled: Bool
  public let rollbackPlan: String
  public var killSwitchEngaged: Bool
  public var rolloutPercentage: Int
  public let projectMayEnable: Bool
  public var userOverrides: [String: Bool]
  public var projectOverrides: [String: Bool]

  public init(
    key: String,
    owner: String,
    purpose: String,
    expiresAt: Date,
    defaultEnabled: Bool,
    rollbackPlan: String,
    killSwitchEngaged: Bool = false,
    rolloutPercentage: Int = 100,
    projectMayEnable: Bool = false,
    userOverrides: [String: Bool] = [:],
    projectOverrides: [String: Bool] = [:]
  ) {
    self.key = key
    self.owner = owner
    self.purpose = purpose
    self.expiresAt = expiresAt
    self.defaultEnabled = defaultEnabled
    self.rollbackPlan = rollbackPlan
    self.killSwitchEngaged = killSwitchEngaged
    self.rolloutPercentage = rolloutPercentage
    self.projectMayEnable = projectMayEnable
    self.userOverrides = userOverrides
    self.projectOverrides = projectOverrides
  }

  public func validationErrors(now: Date) -> [String] {
    var errors: [String] = []
    let safeKeyCharacters = CharacterSet.alphanumerics.union(
      CharacterSet(charactersIn: "._-"))
    if key.isEmpty || key.count > 128
      || !key.unicodeScalars.allSatisfy({ safeKeyCharacters.contains($0) })
    {
      errors.append("feature flag key must be a bounded identifier")
    }
    if owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      errors.append("\(key) requires an owner")
    }
    if purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      errors.append("\(key) requires a purpose")
    }
    if rollbackPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      errors.append("\(key) requires a rollback plan")
    }
    if expiresAt <= now {
      errors.append("\(key) must have a future expiry")
    }
    if !(0...100).contains(rolloutPercentage) {
      errors.append("\(key) rollout percentage must be in 0...100")
    }
    return errors
  }
}

public struct FeatureFlagContext: Sendable, Equatable {
  public let userID: String?
  public let projectID: String?

  public init(userID: String? = nil, projectID: String? = nil) {
    self.userID = userID
    self.projectID = projectID
  }
}

public struct FeatureFlagEvaluation: Codable, Sendable, Equatable {
  public enum Reason: String, Codable, Sendable {
    case killSwitch
    case expired
    case userOverride
    case projectOverride
    case rolloutExcluded
    case rolloutIncluded
    case defaultValue
    case unknownFlag
  }

  public let enabled: Bool
  public let reason: Reason
  public let expiresAt: Date?
}

public enum TuningMetricKind: String, Codable, Sendable, CaseIterable {
  case latencySeconds
  case error
  case energyWatts
  case userCorrection
}

public struct MetricAggregate: Codable, Sendable, Equatable {
  public private(set) var sampleCount: Int = 0
  public private(set) var sum: Double = 0

  public var average: Double {
    sampleCount == 0 ? 0 : sum / Double(sampleCount)
  }

  public mutating func record(_ value: Double) {
    sampleCount += 1
    sum += value
  }
}

public struct TuningRecommendation: Codable, Sendable, Equatable {
  public enum Status: String, Codable, Sendable {
    case pending
    case accepted
    case rejected
  }

  public let id: UUID
  public let key: String
  public let proposedValue: ConfigurationValue
  public let explanation: String
  public let aggregateEvidence: [TuningMetricKind: MetricAggregate]
  public let createdAt: Date
  public var status: Status
}
