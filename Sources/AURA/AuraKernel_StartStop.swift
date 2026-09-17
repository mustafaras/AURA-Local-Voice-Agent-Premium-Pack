import AuraAgent
import AuraAudio
import AuraAutomation
import AuraComputerUse
import AuraConfig
import AuraContext
import AuraCore
import AuraIntent
import AuraMemory
import AuraPlugins
import AuraPolicy
import AuraSTT
import AuraScreen
import AuraSecurity
import AuraShell
import AuraStore
import AuraTasks
import AuraVSCode
import Dispatch
import Foundation

extension AuraKernel {
  // MARK: - Start / stop (subscribe-before-publish ordering)

  /// Every event-bus subscriber must be registered before `audio.start()`
  /// — `AuraEventBus` does not replay history to a late subscriber.
  func startPipeline() async throws(AuraError) {
    guard let taskEngine, let agentTaskRunner, let wakeWordPipeline,
      let intentDispatchCoordinator, let conversationEventBridge, let audioSampleBridge,
      let performanceSampler
    else {
      throw AuraError.invalidConfiguration("AuraKernel.startPipeline called before construct()")
    }

    await taskEngine.start(runner: agentTaskRunner)
    await performanceSampler.start(on: eventBus)
    await voiceResourceGovernor?.start()
    await wakeWordPipeline.start()
    await intentDispatchCoordinator.start()
    await conversationEventBridge.start()
    await audioSampleBridge.start()
    registerLaunchAtLoginAfterStart()
  }

  /// PA-2 / ADR-066 — post-start login-item registration.
  ///
  /// Runs after the pipeline is up and off the start path: `SMAppService`
  /// talks to `backgroundtaskmanagementd` over XPC, and the app's first
  /// render waits on `start()`, so the window must not wait on that round
  /// trip (same reasoning as `probeExternalAvailability`). The controller
  /// call is idempotent — a second launch records `changed: false` — and it
  /// registers the *running* bundle, which is why the installed
  /// `/Applications/AURA.app` must be the one launched (G2-4).
  func registerLaunchAtLoginAfterStart() {
    guard let lifecycleController else { return }
    let logger = logger
    Task.detached {
      let result = await lifecycleController.ensureRegisteredAtLaunch()
      await logger.info(
        "launch-at-login post-start: enabled=\(result.enabled) status=\(result.serviceStatus) "
          + "changed=\(result.changed) (\(result.detail))",
        actor: .lifecycle)
    }
  }

  func shutdownPipeline() async {
    if audioStarted {
      await audio?.stop()
      audioStarted = false
    }
    await audioSampleBridge?.stop()
    await wakeWordPipeline?.stop()
    if sttStarted {
      await sttPipeline?.stop()
      sttStarted = false
    }
    await voiceResourceGovernor?.stop()
    await taskEngine?.shutdown()
    await logger.info("AuraKernel shutdown complete", actor: .system)
  }
}
