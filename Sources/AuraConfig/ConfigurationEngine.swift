import AuraCore
import Foundation

public actor ConfigurationEngine {
  let schema: ConfigurationSchema
  let store: any ConfigurationStateStoring
  let migrations: [ConfigurationMigration]
  let now: @Sendable () -> Date
  let compatibilitySnapshotLimit: Int
  var state: ConfigurationGovernanceState

  init(
    schema: ConfigurationSchema,
    store: any ConfigurationStateStoring,
    migrations: [ConfigurationMigration],
    now: @escaping @Sendable () -> Date,
    compatibilitySnapshotLimit: Int,
    state: ConfigurationGovernanceState
  ) {
    self.schema = schema
    self.store = store
    self.migrations = migrations
    self.now = now
    self.compatibilitySnapshotLimit = compatibilitySnapshotLimit
    self.state = state
  }

}
