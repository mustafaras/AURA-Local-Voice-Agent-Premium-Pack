import AuraCore
import AuraMemory
import Foundation

/// Phase 22's bounded, inspectable context pipeline.
///
/// The builder composes (rather than replaces) Phase 16 `ContextEngine`.
/// It adds typed parsing/schema/entity stages, provenance-graph expansion,
/// reference-graph resolution, per-turn inclusion overrides, and a hard
/// local token estimate. It never evaluates policy or authorizes an action.
public actor ContextBuilder {
  let engine: ContextEngine
  let memory: MemoryEngine
  let eventBus: AuraEventBus
  let configuration: ContextConfiguration
  let resolver: ReferenceResolver

  public init(
    engine: ContextEngine,
    memory: MemoryEngine,
    eventBus: AuraEventBus = .shared,
    configuration: ContextConfiguration = ContextConfiguration()
  ) {
    self.engine = engine
    self.memory = memory
    self.eventBus = eventBus
    self.configuration = configuration
    self.resolver = ReferenceResolver(configuration: configuration)
  }

}
