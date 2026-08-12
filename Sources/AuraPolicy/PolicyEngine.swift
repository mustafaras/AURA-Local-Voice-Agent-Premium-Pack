import AuraCore
import AuraStore
import CryptoKit
import Foundation

/// Actor-isolated policy engine that authorizes every action before execution.
///
/// The engine evaluates requests against deny rules first, then scoped grants,
/// and finally falls back to the configured default tier matrix. It issues
/// tamper-evident confirmation challenges, records audit events on the typed
/// event bus, and persists grants and deny rules through `AuraStore`.
public actor PolicyEngine {
  var configuration: PolicyConfiguration
  var grants: [Grant]
  var denyRules: [DenyRule]
  var pendingConfirmations: [UUID: PolicyConfirmationChallenge]
  var confirmedSessionCapabilities: Set<String>
  let confirmationTransactions: ConfirmationTransactionStore
  let eventBus: AuraEventBus
  let store: AuraStore?
  let jsonEncoder: JSONEncoder
  let jsonDecoder: JSONDecoder

  /// Initialize a new policy engine.
  ///
  /// - Parameters:
  ///   - configuration: Validated policy configuration.
  ///   - eventBus: Event bus used for audit events.
  ///   - store: Optional persistent store for grants and deny rules.
  public init(
    configuration: PolicyConfiguration,
    eventBus: AuraEventBus,
    store: AuraStore? = nil
  ) async throws(AuraError) {
    self.configuration = configuration
    self.grants = []
    self.denyRules = []
    self.pendingConfirmations = [:]
    self.confirmedSessionCapabilities = []
    self.confirmationTransactions = ConfirmationTransactionStore()
    self.eventBus = eventBus
    self.store = store
    self.jsonEncoder = JSONEncoder()
    self.jsonEncoder.dateEncodingStrategy = .iso8601
    self.jsonEncoder.outputFormatting = .sortedKeys
    self.jsonDecoder = JSONDecoder()
    self.jsonDecoder.dateDecodingStrategy = .iso8601
    try await loadFromStore()
  }

}
