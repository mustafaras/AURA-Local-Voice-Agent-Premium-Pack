import AuraAudio
import AuraCore
import AuraSTT
import Foundation

/// Bridges `AuraAudio`'s real captured samples to `WakeWordPipeline`/
/// `STTPipeline`'s `ingestSampleFrame(_:)` seam.
///
/// `AudioFrameEvent` (the event both pipelines already subscribe to)
/// intentionally carries no sample data of its own (`Sources/AuraCore/
/// AudioEventPayloads.swift`) — this bridge reads the real samples via
/// `AuraAudio.latestFrame()` immediately after observing the event, since
/// `AuraAudio.handleCapturedBuffer` appends to the ring buffer before
/// emitting the event (confirmed by reading `Sources/AuraAudio/AuraAudio
/// .swift`), so the frame is already there by the time this subscriber
/// runs. A `sequenceIndex` match is a best-effort staleness check, not a
/// safety-critical one: the wake/STT detectors wired up by this phase
/// (`EnergyVAD`/`MarkerWakeWordDetector`/`DeterministicMockSTTEngine`) do
/// not require bit-exact frame alignment.
///
/// Composition-root-local glue, not a reusable library type — it does not
/// modify `AuraAudio`, `WakeWordPipeline`, or `STTPipeline`'s own logic.
actor AudioSampleBridge {
  private let audio: AuraAudio
  private let wakeWordPipeline: WakeWordPipeline
  private let sttPipeline: STTPipeline
  private let eventBus: AuraEventBus
  private let enableWakeDetection: Bool
  private var subscribed = false

  init(
    audio: AuraAudio, wakeWordPipeline: WakeWordPipeline, sttPipeline: STTPipeline,
    eventBus: AuraEventBus, enableWakeDetection: Bool = true
  ) {
    self.audio = audio
    self.wakeWordPipeline = wakeWordPipeline
    self.sttPipeline = sttPipeline
    self.eventBus = eventBus
    self.enableWakeDetection = enableWakeDetection
  }

  /// Subscribe to `AudioFrameEvent`. Must be called before `AuraAudio
  /// .start()` in `AuraKernel`'s construction sequence.
  func start() async {
    guard !subscribed else { return }
    subscribed = true
    await eventBus.subscribe(AudioFrameEvent.self) { [weak self] envelope in
      await self?.handle(envelope.payload)
    }
  }

  private func handle(_ event: AudioFrameEvent) async {
    guard let frame = await audio.latestFrame(), frame.sequenceIndex == event.sequenceIndex else {
      return
    }
    if enableWakeDetection {
      await wakeWordPipeline.ingestSampleFrame(frame)
    }
    await sttPipeline.ingestSampleFrame(frame)
  }
}
