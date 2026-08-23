import AVFoundation
import AppKit
import AuraCore
import Foundation

private enum CaptureConversionResult {
  case converted(AVAudioPCMBuffer)
  case dropped
  case failed(String)
}

extension AuraAudio {
  // MARK: - Public API

  /// Current capture state.
  public func currentState() -> State {
    state
  }

  /// Current privacy controls.
  public func currentPrivacyControls() -> PrivacyControls {
    privacyControls
  }

  /// Update privacy controls atomically. Emits an indicator event if the visible
  /// indicator setting changes while capture is active.
  public func setPrivacyControls(_ controls: PrivacyControls) async {
    let old = privacyControls
    privacyControls = controls
    if state == .running, old.visibleIndicatorWhenActive != controls.visibleIndicatorWhenActive {
      await emitIndicator(active: controls.visibleIndicatorWhenActive)
    }
  }

  /// Start audio capture if not already running.
  ///
  /// Throws `AuraError.invalidConfiguration` for unsupported settings or
  /// `AuraError.notImplemented` for missing hardware permissions.
  public func start() async throws(AuraError) {
    guard state == .idle || state == .recovering else {
      await logger.warning("start() ignored in state \(state.rawValue)")
      return
    }

    let correlationID = UUID()
    captureCorrelationID = correlationID
    state = .starting
    await logger.info("Starting audio capture", correlationID: correlationID, actor: .audio)

    do {
      let inputFormat = try installCaptureEngine()
      await emitIndicator(active: privacyControls.visibleIndicatorWhenActive)
      await emitCaptureStarted(
        deviceID: inputFormat.channelLayout?.description, correlationID: correlationID)
      observeConfigurationChanges()
      observeSleepWake()

      await logger.info("Audio capture running", correlationID: correlationID, actor: .audio)
    } catch {
      state = .idle
      let message = "Failed to start audio capture: \(error.localizedDescription)"
      await logger.error(message, correlationID: correlationID, actor: .audio)
      await emitCaptureError(message: message, recoverable: true, correlationID: correlationID)
      throw AuraError.notImplemented(message)
    }
  }

  private func installCaptureEngine() throws -> AVAudioFormat {
    let engine = AVAudioEngine()
    self.engine = engine
    let input = engine.inputNode
    let inputFormat = input.outputFormat(forBus: 0)
    guard
      let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: configuration.sampleRate,
        channels: configuration.channelCount, interleaved: false)
    else {
      throw AuraError.invalidConfiguration("Could not construct target audio format")
    }
    guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
      throw AuraError.invalidConfiguration("Cannot convert from \(inputFormat) to \(targetFormat)")
    }
    try input.installAudioTap(
      onBus: 0, bufferSize: UInt32(configuration.captureBufferSize), format: inputFormat
    ) { [weak self] buffer, time in
      guard let self else { return }
      let captureBuffer = CapturedPCMBuffer(AVAudioPCMBuffer(copying: buffer))
      Task { await self.handleCapturedBuffer(captureBuffer, time: time, converter: converter) }
    }
    try engine.start()
    state = .running
    totalFrames = 0
    sequenceIndex = 0
    lastTapTimestamp = 0
    return inputFormat
  }

  /// Stop audio capture and tear down the engine.
  public func stop(reason: String = "requested") async {
    guard state == .running || state == .starting || state == .recovering else {
      await logger.warning("stop() ignored in state \(state.rawValue)")
      return
    }

    state = .stopping
    let correlationID = captureCorrelationID ?? UUID()
    await logger.info(
      "Stopping audio capture: \(reason)", correlationID: correlationID, actor: .audio)

    // Tear down the synchronous observers first so no configuration-change or
    // sleep/wake notification can reach a handler after teardown begins.
    removeObservers()
    // An explicit stop must survive a later wake: clearing this is what stops
    // the microphone reopening on its own after the user closed it.
    shouldResumeAfterWake = false

    if let engine = engine {
      engine.stop()
      engine.inputNode.removeTap(onBus: 0)
      self.engine = nil
    }

    ringBuffer.clear()
    await emitIndicator(active: false)
    await emitCaptureStopped(reason: reason, totalFrames: totalFrames, correlationID: correlationID)

    state = .idle
    await logger.info("Audio capture stopped", correlationID: correlationID, actor: .audio)
  }

  /// Return a snapshot of the ring buffer without stopping capture.
  public func ringBufferSnapshot() -> [AudioFrame] {
    ringBuffer.snapshot()
  }

  /// The most recently captured frame, or `nil` before capture has produced
  /// any. `AudioFrameEvent` (the bus event `handleCapturedBuffer` emits
  /// after appending to the ring buffer) intentionally carries no sample
  /// data of its own; a subscriber that needs the real samples for a given
  /// frame calls this immediately after observing the event.
  public func latestFrame() -> AudioFrame? {
    ringBuffer.latest()
  }

  /// Return a retained frame by its capture sequence index.
  public func frame(sequenceIndex: UInt64) -> AudioFrame? {
    ringBuffer.frame(sequenceIndex: sequenceIndex)
  }

  /// Total frames captured during the current or most recent session.
  public func capturedFrameCount() -> UInt64 {
    totalFrames
  }

  // MARK: - Tap handling

  private func handleCapturedBuffer(
    _ captured: CapturedPCMBuffer,
    time: AVAudioTime,
    converter: AVAudioConverter
  ) async {
    guard state == .running else { return }
    let captureBuffer = captured.value
    let now = monotonicClock()
    let isDiscontinuity = captureTiming(for: captureBuffer, now: now)
    switch convert(captureBuffer, using: converter) {
    case .dropped:
      return
    case .failed(let message):
      await emitCaptureError(
        message: message,
        recoverable: true,
        correlationID: captureCorrelationID
      )
      return
    case .converted(let outputBuffer):
      guard
        let frame = makeFrame(
          from: outputBuffer, timestamp: now, isDiscontinuity: isDiscontinuity)
      else { return }
      ringBuffer.append(frame)
      sequenceIndex &+= 1
      totalFrames &+= 1
      await emitFrameEvent(
        sampleCount: frame.samples.count, timestamp: now, sequenceIndex: frame.sequenceIndex,
        isDiscontinuity: isDiscontinuity, correlationID: captureCorrelationID)
    }
  }

  private func captureTiming(for buffer: AVAudioPCMBuffer, now: TimeInterval) -> Bool {
    defer { lastTapTimestamp = now }
    guard lastTapTimestamp > 0 else { return false }
    let expectedInterval = Double(buffer.frameLength) / buffer.format.sampleRate
    return now - lastTapTimestamp > expectedInterval * 2
  }

  private func convert(
    _ captureBuffer: AVAudioPCMBuffer,
    using converter: AVAudioConverter
  ) -> CaptureConversionResult {
    guard
      let outputBuffer = AVAudioPCMBuffer(
        pcmFormat: converter.outputFormat,
        frameCapacity: AVAudioFrameCount(configuration.frameLength))
    else {
      return .failed("Could not allocate conversion buffer")
    }
    var error: NSError?
    var suppliedInput = false
    let inputProvider: AVAudioConverterInputBlock = { _, outStatus in
      guard !suppliedInput else {
        outStatus.pointee = .noDataNow
        return nil
      }
      suppliedInput = true
      outStatus.pointee = .haveData
      return captureBuffer
    }
    let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputProvider)

    if let error { return .failed("Audio converter error: \(error.localizedDescription)") }

    guard status != .error, outputBuffer.frameLength > 0,
      let floatChannelData = outputBuffer.floatChannelData
    else {
      return .dropped
    }
    _ = floatChannelData
    return .converted(outputBuffer)
  }

  private func makeFrame(
    from outputBuffer: AVAudioPCMBuffer,
    timestamp: TimeInterval,
    isDiscontinuity: Bool
  ) -> AudioFrame? {
    guard let floatChannelData = outputBuffer.floatChannelData else { return nil }
    let frameLength = Int(outputBuffer.frameLength)
    let samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))
    return AudioFrame(
      samples: samples,
      timestamp: timestamp,
      sequenceIndex: sequenceIndex,
      isDiscontinuity: isDiscontinuity
    )
  }

  // MARK: - Device change recovery

  /// Register a synchronous `NotificationCenter` observer for device changes.
  ///
  /// This is intentionally synchronous: `addObserver` returns only after the
  /// observer is registered, so once `start()` returns a device-change
  /// notification posted immediately afterwards is guaranteed to be delivered.
  /// (The previous `Task { for await }` pattern could return from `start()`
  /// before its subscription was live, silently dropping notifications and
  /// wedging the recovery path.)
  private func observeConfigurationChanges() {
    guard configurationChangeObserver == nil else { return }
    configurationChangeObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange,
      object: nil,
      queue: nil
    ) { [weak self] _ in
      Task { [weak self] in
        await self?.handleConfigurationChange()
      }
    }
  }

  /// Sleep tears audio hardware down underneath a running engine, and on wake
  /// the tap is dead: capture reports `.running` while delivering nothing. The
  /// user discovers this by pressing Push to Talk and being met with silence,
  /// which is the worst possible failure for a voice agent because it looks
  /// like the agent ignored them.
  ///
  /// Suspend deliberately on sleep and resume on wake, but only when capture
  /// was actually running when sleep began.
  private func observeSleepWake() {
    guard sleepObserver == nil, wakeObserver == nil else { return }
    let center = NSWorkspace.shared.notificationCenter
    sleepObserver = center.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: nil
    ) { [weak self] _ in
      Task { [weak self] in
        await self?.handleSystemWillSleep()
      }
    }
    wakeObserver = center.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: nil
    ) { [weak self] _ in
      Task { [weak self] in
        await self?.handleSystemDidWake()
      }
    }
  }

  /// Remove every synchronous observer. Idempotent; safe to call in `stop()`.
  private func removeObservers() {
    let center = NotificationCenter.default
    let workspaceCenter = NSWorkspace.shared.notificationCenter
    if let configurationChangeObserver {
      center.removeObserver(configurationChangeObserver)
      self.configurationChangeObserver = nil
    }
    if let sleepObserver {
      workspaceCenter.removeObserver(sleepObserver)
      self.sleepObserver = nil
    }
    if let wakeObserver {
      workspaceCenter.removeObserver(wakeObserver)
      self.wakeObserver = nil
    }
  }

  private func handleSystemWillSleep() async {
    guard state == .running else { return }
    let correlationID = captureCorrelationID ?? UUID()
    await logger.info(
      "System sleeping; suspending audio capture",
      correlationID: correlationID,
      actor: .audio
    )

    shouldResumeAfterWake = true
    state = .recovering
    if let engine = engine {
      engine.stop()
      engine.inputNode.removeTap(onBus: 0)
      self.engine = nil
    }
    // The indicator must go dark: the microphone is genuinely closed, and a
    // lit indicator over a dead tap is a privacy lie in the wrong direction.
    await emitIndicator(active: false)
    await emitCaptureError(
      message: "Audio capture suspended for system sleep; recovering on wake",
      recoverable: true,
      correlationID: correlationID
    )
  }

  private func handleSystemDidWake() async {
    guard shouldResumeAfterWake else { return }
    shouldResumeAfterWake = false
    let correlationID = captureCorrelationID ?? UUID()
    await logger.info(
      "System woke; resuming audio capture", correlationID: correlationID, actor: .audio)

    do {
      try await start()
    } catch {
      let message = "Resume after wake failed: \(error.localizedDescription)"
      await logger.error(message, correlationID: correlationID, actor: .audio)
      state = .idle
      await emitCaptureError(message: message, recoverable: false, correlationID: correlationID)
    }
  }

  private func handleConfigurationChange() async {
    guard state == .running else { return }
    let correlationID = captureCorrelationID ?? UUID()
    await logger.warning(
      "Audio engine configuration changed; restarting capture",
      correlationID: correlationID,
      actor: .audio
    )

    state = .recovering
    await emitCaptureError(
      message: "Audio device configuration changed; recovering",
      recoverable: true,
      correlationID: correlationID
    )

    if let engine = engine {
      engine.stop()
      engine.inputNode.removeTap(onBus: 0)
    }

    // Brief backoff to let hardware settle.
    try? await Task.sleep(nanoseconds: 50_000_000)

    do {
      try await start()
    } catch {
      let message = "Recovery start failed: \(error.localizedDescription)"
      await logger.error(message, correlationID: correlationID, actor: .audio)
      state = .idle
      await emitCaptureError(message: message, recoverable: false, correlationID: correlationID)
    }
  }

  // MARK: - Event helpers

  private func emitCaptureStarted(deviceID: String?, correlationID: UUID?) async {
    let envelope = EventEnvelope(
      correlationID: correlationID ?? UUID(),
      causationID: correlationID ?? UUID(),
      actor: .audio,
      sensitivity: .internalLevel,
      payload: AudioCaptureStartedEvent(
        deviceID: deviceID,
        sampleRate: configuration.sampleRate,
        channelCount: configuration.channelCount
      )
    )
    await eventBus.emit(envelope)
  }

  private func emitFrameEvent(
    sampleCount: Int,
    timestamp: TimeInterval,
    sequenceIndex: UInt64,
    isDiscontinuity: Bool,
    correlationID: UUID?
  ) async {
    let envelope = EventEnvelope(
      correlationID: correlationID ?? UUID(),
      causationID: correlationID ?? UUID(),
      actor: .audio,
      sensitivity: .internalLevel,
      payload: AudioFrameEvent(
        sampleCount: sampleCount,
        timestamp: timestamp,
        sequenceIndex: sequenceIndex,
        isDiscontinuity: isDiscontinuity
      )
    )
    await eventBus.emit(envelope)
  }

  private func emitCaptureStopped(reason: String, totalFrames: UInt64, correlationID: UUID?) async {
    let envelope = EventEnvelope(
      correlationID: correlationID ?? UUID(),
      causationID: correlationID ?? UUID(),
      actor: .audio,
      sensitivity: .internalLevel,
      payload: AudioCaptureStoppedEvent(reason: reason, totalFrames: totalFrames)
    )
    await eventBus.emit(envelope)
  }

  private func emitCaptureError(message: String, recoverable: Bool, correlationID: UUID?) async {
    let envelope = EventEnvelope(
      correlationID: correlationID ?? UUID(),
      causationID: correlationID ?? UUID(),
      actor: .audio,
      sensitivity: .internalLevel,
      payload: AudioCaptureErrorEvent(errorMessage: message, recoverable: recoverable)
    )
    await eventBus.emit(envelope)
  }

  private func emitIndicator(active: Bool) async {
    let envelope = EventEnvelope(
      correlationID: captureCorrelationID ?? UUID(),
      causationID: captureCorrelationID ?? UUID(),
      actor: .system,
      sensitivity: .publicLevel,
      payload: AudioIndicatorEvent(isActive: active)
    )
    await eventBus.emit(envelope)
  }
}
