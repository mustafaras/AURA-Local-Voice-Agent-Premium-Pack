import AuraAgent
import AuraCore
import AuraPlugins
import AuraTasks

struct AuraKernelExtensions {
  let ollamaAdapter: OllamaAdapter?
}

extension AuraKernel {
  func constructExtensions(
    _ foundation: AuraKernelFoundation,
    _ agents: AuraKernelAgents
  ) async throws(AuraError) -> AuraKernelExtensions {
    try await constructPluginSubsystem(foundation)

    let ollama: OllamaAdapter?
    let ollamaHealth: (RuntimeHealthStatus, String)
    do {
      ollama = try OllamaAdapter(
        configuration: configuration.ollama, policyEngine: foundation.policyEngine,
        approvalPresenter: confirmationPresenter, eventBus: eventBus)
      ollamaHealth = (.ready, "adapter constructed")
    } catch {
      ollama = nil
      ollamaHealth = (.degraded, "local model adapter unavailable: \(error.localizedDescription)")
    }
    ollamaAdapter = ollama
    await foundation.runtimeHealthRegistry.record(
      componentID: "ollama", status: ollamaHealth.0, detail: ollamaHealth.1)

    let worktree = WorktreeManager(
      configuration: configuration.worktree,
      policyEngine: foundation.policyEngine,
      eventBus: eventBus)
    self.worktreeManager = worktree
    await foundation.runtimeHealthRegistry.recordReady(
      "worktrees", detail: "isolated worktree manager constructed")
    self.codingTaskCoordinator = CodingTaskCoordinator(
      taskEngine: foundation.taskEngine, backendRunner: agents.taskRunner,
      healthRegistry: agents.healthRegistry, worktreeManager: worktree)
    await foundation.runtimeHealthRegistry.recordReady(
      "coding-tasks", detail: "workspace/backend/worktree/durable-task coordinator constructed")
    multiAgentOrchestrator = MultiAgentOrchestrator(
      worktreeManager: worktree, policyEngine: foundation.policyEngine,
      validationShell: foundation.shell, eventBus: eventBus)
    await foundation.runtimeHealthRegistry.recordReady(
      "multi-agent", detail: "bounded multi-agent orchestrator constructed")
    return AuraKernelExtensions(ollamaAdapter: ollama)
  }

  private func constructPluginSubsystem(
    _ foundation: AuraKernelFoundation
  ) async throws(AuraError) {
    let verifier = PluginVerifier(
      trustRegistry: PluginTrustRegistry(configuration: configuration.plugins))
    let runtimeComponents: PluginRuntimeComponents?
    let pluginHealthDetail: String?
    do {
      runtimeComponents = try PluginRuntimeFactory.make(configuration: configuration.plugins)
      pluginHealthDetail = nil
    } catch {
      runtimeComponents = nil
      pluginHealthDetail = "plugin runtime unavailable: \(error.localizedDescription)"
    }
    if let pluginHealthDetail {
      await foundation.runtimeHealthRegistry.record(
        componentID: "plugins", status: .degraded,
        detail: "\(pluginHealthDetail); registry remains fail-closed")
    } else {
      await foundation.runtimeHealthRegistry.recordReady(
        "plugins", detail: "verified plugin runtime constructed")
    }
    pluginRegistry = try await PluginRegistry(
      verifier: verifier, policyEngine: foundation.policyEngine, store: store, eventBus: eventBus,
      artifactStore: runtimeComponents?.artifactStore, runtimeHost: runtimeComponents?.runtimeHost,
      configuration: configuration.plugins)
  }
}
