import AuraCore
import AuraPolicy
import AuraStore
import Foundation

/// Verified plugin lifecycle, artifact, grant, audit, and runtime coordinator.
public actor PluginRegistry {
  var records: [String: PluginRecord]
  let verifier: PluginVerifier
  let policyEngine: PolicyEngine
  let store: AuraStore?
  let eventBus: AuraEventBus?
  let artifactStore: PluginArtifactStore?
  let runtimeHost: (any PluginRuntimeHosting)?
  let configuration: PluginConfiguration
  let jsonEncoder: JSONEncoder
  let jsonDecoder: JSONDecoder

  public init(
    verifier: PluginVerifier,
    policyEngine: PolicyEngine,
    store: AuraStore? = nil,
    eventBus: AuraEventBus? = nil,
    artifactStore: PluginArtifactStore? = nil,
    runtimeHost: (any PluginRuntimeHosting)? = nil,
    configuration: PluginConfiguration = PluginConfiguration()
  ) async throws(AuraError) {
    self.verifier = verifier
    self.policyEngine = policyEngine
    self.store = store
    self.eventBus = eventBus
    self.artifactStore = artifactStore
    self.runtimeHost = runtimeHost
    self.configuration = configuration
    self.records = [:]
    self.jsonEncoder = JSONEncoder()
    self.jsonEncoder.dateEncodingStrategy = .iso8601
    self.jsonEncoder.outputFormatting = .sortedKeys
    self.jsonDecoder = JSONDecoder()
    self.jsonDecoder.dateDecodingStrategy = .iso8601
    try await loadFromStore()
  }

}
