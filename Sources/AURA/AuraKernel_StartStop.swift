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
