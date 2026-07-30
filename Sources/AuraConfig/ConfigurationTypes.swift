import Foundation

public enum ConfigurationLayer: String, Codable, Sendable, CaseIterable, Comparable {
  case secureDefaults
  case machinePolicy
  case userSettings
  case projectSettings
  case sessionOverrides

  public static func < (lhs: ConfigurationLayer, rhs: ConfigurationLayer) -> Bool {
    guard
      let left = allCases.firstIndex(of: lhs),
      let right = allCases.firstIndex(of: rhs)
    else { return false }
    return left < right
  }
}

public enum ConfigurationValueType: String, Codable, Sendable {
  case boolean
  case integer
  case number
  case string
  case stringList
}

public enum ConfigurationValue: Codable, Sendable, Equatable {
  case boolean(Bool)
  case integer(Int)
  case number(Double)
  case string(String)
  case stringList([String])

  public var valueType: ConfigurationValueType {
    switch self {
    case .boolean: .boolean
    case .integer: .integer
    case .number: .number
    case .string: .string
    case .stringList: .stringList
    }
  }

  public var displayValue: String {
    switch self {
    case .boolean(let value): String(value)
    case .integer(let value): String(value)
    case .number(let value): String(format: "%.4g", value)
    case .string(let value): value
    case .stringList(let value): value.joined(separator: ", ")
    }
  }
}

/// The direction in which a lower-trust layer may change a security value.
public enum SecurityConstraint: String, Codable, Sendable {
  case unrestricted
  case immutable
  case mayNotIncrease
  case mayNotDecrease
  case mayOnlyNarrow
}

public struct ConfigurationKeyDefinition: Codable, Sendable, Equatable {
  public let key: String
  public let purpose: String
  public let defaultValue: ConfigurationValue
  public let allowedLayers: Set<ConfigurationLayer>
  public let projectConstraint: SecurityConstraint
  public let machinePolicyEnforced: Bool
  public let minimumNumber: Double?
  public let maximumNumber: Double?
  public let sensitive: Bool

  public init(
    key: String,
    purpose: String,
    defaultValue: ConfigurationValue,
    allowedLayers: Set<ConfigurationLayer> = Set(ConfigurationLayer.allCases.dropFirst()),
    projectConstraint: SecurityConstraint = .unrestricted,
    machinePolicyEnforced: Bool = false,
    minimumNumber: Double? = nil,
    maximumNumber: Double? = nil,
    sensitive: Bool = false
  ) {
    self.key = key
    self.purpose = purpose
    self.defaultValue = defaultValue
    self.allowedLayers = allowedLayers
    self.projectConstraint = projectConstraint
    self.machinePolicyEnforced = machinePolicyEnforced
    self.minimumNumber = minimumNumber
    self.maximumNumber = maximumNumber
    self.sensitive = sensitive
  }

  public func validate(_ value: ConfigurationValue) -> String? {
    guard value.valueType == defaultValue.valueType else {
      return "\(key) expects \(defaultValue.valueType.rawValue), got \(value.valueType.rawValue)"
    }
    if sensitive {
      return "\(key) is sensitive and must be stored in Keychain, not configuration"
    }
    let number: Double?
    switch value {
    case .integer(let value): number = Double(value)
    case .number(let value): number = value
    default: number = nil
    }
    if let number, !number.isFinite {
      return "\(key) must be finite"
    }
    if let minimumNumber, let number, number < minimumNumber {
      return "\(key) must be at least \(minimumNumber)"
    }
    if let maximumNumber, let number, number > maximumNumber {
      return "\(key) must be at most \(maximumNumber)"
    }
    return nil
  }
}

public struct ConfigurationSchema: Codable, Sendable, Equatable {
  public let version: String
  public let definitions: [String: ConfigurationKeyDefinition]

  public init(version: String, definitions: [ConfigurationKeyDefinition]) {
    self.version = version
    self.definitions = Dictionary(uniqueKeysWithValues: definitions.map { ($0.key, $0) })
  }

  public static let phase24 = ConfigurationSchema(
    version: "1.0.0",
    definitions: [
      ConfigurationKeyDefinition(
        key: "policy.maximumAllowByDefaultRisk",
        purpose: "Highest risk tier that may run without an explicit grant",
        defaultValue: .integer(0),
        projectConstraint: .mayNotIncrease,
        machinePolicyEnforced: true,
        minimumNumber: 0,
        maximumNumber: 3),
      ConfigurationKeyDefinition(
        key: "policy.minimumConfirmationRisk",
        purpose: "Lowest risk tier that always requires confirmation",
        defaultValue: .integer(2),
        projectConstraint: .mayNotDecrease,
        machinePolicyEnforced: true,
        minimumNumber: 0,
        maximumNumber: 3),
      ConfigurationKeyDefinition(
        key: "security.allowedNetworkDomains",
        purpose: "Explicit non-secret outbound domain allowlist",
        defaultValue: .stringList([]),
        projectConstraint: .mayOnlyNarrow,
        machinePolicyEnforced: true),
      ConfigurationKeyDefinition(
        key: "privacy.rawTelemetryEnabled",
        purpose: "Raw telemetry is forbidden by the local-first privacy boundary",
        defaultValue: .boolean(false),
        projectConstraint: .immutable,
        machinePolicyEnforced: true),
      ConfigurationKeyDefinition(
        key: "privacy.localRecommendationsEnabled",
        purpose: "User opt-in for local aggregate tuning recommendations",
        defaultValue: .boolean(false),
        allowedLayers: [.userSettings, .sessionOverrides]),
      ConfigurationKeyDefinition(
        key: "audio.vad.silenceEndFrames",
        purpose: "Silence frames required to close a spoken turn",
        defaultValue: .integer(20),
        minimumNumber: 3,
        maximumNumber: 100),
      ConfigurationKeyDefinition(
        key: "stt.stabilizationDelayFrames",
        purpose: "Frames required before accepting a stable transcript",
        defaultValue: .integer(2),
        minimumNumber: 1,
        maximumNumber: 20),
      ConfigurationKeyDefinition(
        key: "models.maxConcurrentLocalModels",
        purpose: "Bound concurrent local model residency",
        defaultValue: .integer(1),
        projectConstraint: .mayNotIncrease,
        machinePolicyEnforced: true,
        minimumNumber: 1,
        maximumNumber: 3),
      ConfigurationKeyDefinition(
        key: "performance.wakeAcknowledgementBudgetSeconds",
        purpose: "Wake-to-acknowledgement latency budget",
        defaultValue: .number(0.5),
        minimumNumber: 0.1,
        maximumNumber: 2.0),
      ConfigurationKeyDefinition(
        key: "performance.energyBudgetWatts",
        purpose: "Average local processing energy budget",
        defaultValue: .number(6),
        minimumNumber: 1,
        maximumNumber: 20),
    ])
}

public struct ConfigurationPatch: Codable, Sendable, Equatable {
  public let layer: ConfigurationLayer
  public let values: [String: ConfigurationValue]
  public let source: String

  public init(layer: ConfigurationLayer, values: [String: ConfigurationValue], source: String) {
    self.layer = layer
    self.values = values
    self.source = source
  }
}

public struct EffectiveConfigurationEntry: Codable, Sendable, Equatable {
  public let key: String
  public let value: ConfigurationValue
  public let sourceLayer: ConfigurationLayer
  public let differsFromDefault: Bool
}

public struct ConfigurationInspection: Codable, Sendable, Equatable {
  public let schemaVersion: String
  public let entries: [EffectiveConfigurationEntry]
  public let unknownKeyWarnings: [String]
}

public struct ConfigurationChangeResult: Codable, Sendable, Equatable {
  public let accepted: Bool
  public let warnings: [String]
  public let auditID: UUID
}
