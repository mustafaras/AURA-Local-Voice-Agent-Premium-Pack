import AuraCore
import AuraStore
import Foundation

public struct ConfigurationAuditRecord: Codable, Sendable, Equatable {
  public let id: UUID
  public let timestamp: Date
  public let action: String
  public let actor: ActorID
  public let accepted: Bool
  public let layer: ConfigurationLayer?
  public let keys: [String]
  public let detail: String
}

public struct ConfigurationSnapshot: Codable, Sendable, Equatable {
  public let id: UUID
  public let timestamp: Date
  public let reason: String
  public let schemaVersion: String
  public let layers: [ConfigurationLayer: [String: ConfigurationValue]]
  public let featureFlags: [String: FeatureFlagDefinition]
}

public struct ConfigurationGovernanceState: Codable, Sendable, Equatable {
  public var schemaVersion: String
  public var layers: [ConfigurationLayer: [String: ConfigurationValue]]
  public var featureFlags: [String: FeatureFlagDefinition]
  public var telemetry: [TuningMetricKind: MetricAggregate]
  public var recommendations: [TuningRecommendation]
  public var snapshots: [ConfigurationSnapshot]
  public var audit: [ConfigurationAuditRecord]
  public var migrationHistory: [String]
  public var unknownKeyWarnings: [String]

  public init(schema: ConfigurationSchema) {
    self.schemaVersion = schema.version
    self.layers = [
      .secureDefaults: schema.definitions.mapValues(\.defaultValue),
      .machinePolicy: [:],
      .userSettings: [:],
      .projectSettings: [:],
      .sessionOverrides: [:],
    ]
    self.featureFlags = [:]
    self.telemetry = [:]
    self.recommendations = []
    self.snapshots = []
    self.audit = []
    self.migrationHistory = []
    self.unknownKeyWarnings = []
  }
}

public struct ConfigurationMigration: Codable, Sendable, Equatable {
  public let fromVersion: String
  public let toVersion: String
  public let renamedKeys: [String: String]

  public init(fromVersion: String, toVersion: String, renamedKeys: [String: String]) {
    self.fromVersion = fromVersion
    self.toVersion = toVersion
    self.renamedKeys = renamedKeys
  }

  public func migrateForward(_ state: ConfigurationGovernanceState)
    -> ConfigurationGovernanceState
  {
    var migrated = state
    migrated.layers = rename(in: state.layers, mapping: renamedKeys)
    migrated.schemaVersion = toVersion
    migrated.migrationHistory.append("\(fromVersion)->\(toVersion)")
    return migrated
  }

  public func migrateReverse(_ state: ConfigurationGovernanceState)
    -> ConfigurationGovernanceState
  {
    var migrated = state
    let reverse = Dictionary(uniqueKeysWithValues: renamedKeys.map { ($1, $0) })
    migrated.layers = rename(in: state.layers, mapping: reverse)
    migrated.schemaVersion = fromVersion
    migrated.migrationHistory.append("\(toVersion)->\(fromVersion)")
    return migrated
  }

  private func rename(
    in layers: [ConfigurationLayer: [String: ConfigurationValue]],
    mapping: [String: String]
  ) -> [ConfigurationLayer: [String: ConfigurationValue]] {
    layers.mapValues { values in
      var migrated = values
      for (oldKey, newKey) in mapping {
        if let value = migrated.removeValue(forKey: oldKey) {
          migrated[newKey] = value
        }
      }
      return migrated
    }
  }
}

public protocol ConfigurationStateStoring: Sendable {
  func loadState() async throws(AuraError) -> ConfigurationGovernanceState?
  func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError)
}

public actor AuraStoreConfigurationStateStore: ConfigurationStateStoring {
  public static let defaultKey = "configuration.governance.state.v1"

  private let store: AuraStore
  private let key: String
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(store: AuraStore, key: String = defaultKey) {
    self.store = store
    self.key = key
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
    self.encoder.outputFormatting = [.sortedKeys]
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
  }

  public func loadState() async throws(AuraError) -> ConfigurationGovernanceState? {
    guard let value = try await store.value(forKey: key), let data = value.data(using: .utf8)
    else { return nil }
    do {
      return try decoder.decode(ConfigurationGovernanceState.self, from: data)
    } catch {
      throw AuraError.serializationError(
        "configuration state decode failed: \(error.localizedDescription)")
    }
  }

  public func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError) {
    do {
      let data = try encoder.encode(state)
      guard let value = String(data: data, encoding: .utf8) else {
        throw AuraError.serializationError("configuration state is not UTF-8")
      }
      // One SQLite upsert commits the complete envelope or none of it.
      try await store.setValue(value, forKey: key)
    } catch let error as AuraError {
      throw error
    } catch {
      throw AuraError.serializationError(
        "configuration state encode failed: \(error.localizedDescription)")
    }
  }
}
