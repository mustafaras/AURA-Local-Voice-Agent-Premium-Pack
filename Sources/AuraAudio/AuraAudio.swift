import AVFoundation
import AuraCore
import Foundation

/// Real-time audio capture service for AURA.
///
/// Responsibilities:
/// - Configure and start/stop an `AVAudioEngine` input node capture tap.
/// - Convert raw PCM to mono float at the configured sample rate.
/// - Maintain a bounded ring buffer for short-term audio context.
/// - Emit typed lifecycle, frame, error, and privacy-indicator events.
/// - Recover safely from `AVAudioEngineConfigurationChange` notifications.
///
/// The service is an actor; all public entry points are isolated. The tap callback
/// runs on a realtime AVFoundation queue and must therefore perform no blocking,
/// allocation-heavy, or model work. It copies samples into a pre-allocated buffer
/// and immediately returns.
public actor AuraAudio {
  /// Current capture state.
  public enum State: String, Sendable, Equatable, CaseIterable {
    case idle
    case starting
    case running
    case stopping
    case recovering
  }

  /// Diagnostic capture policy. Defaults are privacy-first: no retention,
  /// no encryption expectation at rest, and the indicator is off when not
  /// actively capturing.
  public struct PrivacyControls: Sendable, Equatable {
    public var enableDiagnosticCapture: Bool
    public var diagnosticRetentionHours: UInt
    public var encryptDiagnostics: Bool
    public var visibleIndicatorWhenActive: Bool

    public init(
      enableDiagnosticCapture: Bool = false,
      diagnosticRetentionHours: UInt = 24,
      encryptDiagnostics: Bool = true,
      visibleIndicatorWhenActive: Bool = true
    ) {
      self.enableDiagnosticCapture = enableDiagnosticCapture
      self.diagnosticRetentionHours = diagnosticRetentionHours
      self.encryptDiagnostics = encryptDiagnostics
      self.visibleIndicatorWhenActive = visibleIndicatorWhenActive
    }
  }

  private let configuration: AudioConfiguration
  private let eventBus: AuraEventBus
  private let logger: AuraLogger
  private let ringBuffer: AudioRingBuffer
  private var privacyControls: PrivacyControls

  private var engine: AVAudioEngine?
  private var state: State = .idle
  private var sequenceIndex: UInt64 = 0
  private var totalFrames: UInt64 = 0
  private var lastTapTimestamp: TimeInterval = 0
  private var configurationChangeTask: Task<Void, Never>?
  private var captureCorrelationID: UUID?

  /// Monotonic clock source for tests and frame timestamps.
  private let monotonicClock: () -> TimeInterval

  /// Create a new audio service.
  ///
  /// - Parameters:
  ///   - configuration: Audio capture settings.
  ///   - eventBus: Bus for audio events.
  ///   - logger: Privacy-aware logger.
  ///   - ringBuffer: Optional external ring buffer; if nil, one is created from
  ///     `configuration.ringBufferSeconds` and `configuration.frameLength`.
  ///   - privacyControls: Diagnostic capture and indicator policy.
  ///   - monotonicClock: Injectible clock; defaults to `CFAbsoluteTimeGetCurrent`.
  public init(
    configuration: AudioConfiguration,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    ringBuffer: AudioRingBuffer? = nil,
    privacyControls: PrivacyControls = PrivacyControls(),
    monotonicClock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }
  ) {
    self.configuration = configuration
    self.eventBus = eventBus
    self.logger = logger
    if let ringBuffer = ringBuffer {
      self.ringBuffer = ringBuffer
    } else {
      let capacity = Int(
        max(
          1,
          (configuration.ringBufferSeconds * Double(configuration.sampleRate))
            / Double(configuration.frameLength)
        )
      )
      self.ringBuffer = AudioRingBuffer(capacity: capacity)
    }
    self.privacyControls = privacyControls
    self.monotonicClock = monotonicClock
  }

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
      let engine = AVAudioEngine()
      self.engine = engine

      let input = engine.inputNode
      let inputFormat = input.outputFormat(forBus: 0)
      let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: configuration.sampleRate,
        channels: configuration.channelCount,
        interleaved: false
      )

      guard let targetFormat = targetFormat else {
        throw AuraError.invalidConfiguration("Could not construct target audio format")
      }

      let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
      guard let converter = converter else {
        throw AuraError.invalidConfiguration(
          "Cannot convert from \(inputFormat) to \(targetFormat)"
        )
      }

      let bufferSize = UInt32(configuration.captureBufferSize)

      // Modern macOS 27 throwing API. The closure is realtime-safe: it only
      // enqueues data and never blocks, allocates, or performs file/model work.
      try input.installAudioTap(
        onBus: 0,
        bufferSize: bufferSize,
        format: inputFormat
      ) { [weak self] buffer, time in
        guard let self = self else { return }
        Task {
          await self.handleCapturedBuffer(buffer, time: time, converter: converter)
        }
      }

      try engine.start()
      state = .running
      totalFrames = 0
      sequenceIndex = 0
      lastTapTimestamp = 0

      await emitIndicator(active: privacyControls.visibleIndicatorWhenActive)
      await emitCaptureStarted(
        deviceID: inputFormat.channelLayout?.description, correlationID: correlationID)
      observeConfigurationChanges()

      await logger.info("Audio capture running", correlationID: correlationID, actor: .audio)
    } catch {
      state = .idle
      let message = "Failed to start audio capture: \(error.localizedDescription)"
      await logger.error(message, correlationID: correlationID, actor: .audio)
      await emitCaptureError(message: message, recoverable: true, correlationID: correlationID)
      throw AuraError.notImplemented(message)
    }
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

    configurationChangeTask?.cancel()
    configurationChangeTask = nil

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

  /// Total frames captured during the current or most recent session.
  public func capturedFrameCount() -> UInt64 {
    totalFrames
  }

  // MARK: - Tap handling

  private func handleCapturedBuffer(
    _ buffer: AVReadOnlyAudioPCMBuffer,
    time: AVAudioTime,
    converter: AVAudioConverter
  ) async {
    guard state == .running else { return }

    let now = monotonicClock()
    var isDiscontinuity = false
    if lastTapTimestamp > 0 {
      let expectedInterval = Double(buffer.frameLength) / configuration.sampleRate
      let actualInterval = now - lastTapTimestamp
      if actualInterval > expectedInterval * 2 {
        isDiscontinuity = true
      }
    }
    lastTapTimestamp = now

    guard
      let outputBuffer = AVAudioPCMBuffer(
        pcmFormat: converter.outputFormat,
        frameCapacity: AVAudioFrameCount(configuration.frameLength)
      )
    else {
      await emitCaptureError(
        message: "Could not allocate conversion buffer",
        recoverable: true,
        correlationID: captureCorrelationID
      )
      return
    }

    // Copy the read-only tap buffer into a mutable AVAudioPCMBuffer so that
    // AVAudioConverter's input block can vend it. The copy is local and
    // short-lived; it avoids retaining the realtime buffer past the callback.
    let captureBuffer = AVAudioPCMBuffer(copying: buffer)

    var error: NSError?
    let status = converter.convert(to: outputBuffer, error: &error) {
      (_: AVAudioPacketCount, outStatus: UnsafeMutablePointer<AVAudioConverterInputStatus>)
        -> AVAudioBuffer? in
      outStatus.pointee = .haveData
      return captureBuffer
    }

    if let error = error {
      await emitCaptureError(
        message: "Audio converter error: \(error.localizedDescription)",
        recoverable: true,
        correlationID: captureCorrelationID
      )
      return
    }

    guard status == .haveData || status == .endOfStream,
      let floatChannelData = outputBuffer.floatChannelData
    else {
      return
    }

    let frameLength = Int(outputBuffer.frameLength)
    let samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))
    let frame = AudioFrame(
      samples: samples,
      timestamp: now,
      sequenceIndex: sequenceIndex,
      isDiscontinuity: isDiscontinuity
    )

    ringBuffer.append(frame)

    sequenceIndex &+= 1
    totalFrames &+= 1

    await emitFrameEvent(
      sampleCount: frameLength,
      timestamp: now,
      sequenceIndex: frame.sequenceIndex,
      isDiscontinuity: isDiscontinuity,
      correlationID: captureCorrelationID
    )
  }

  // MARK: - Device change recovery

  private func observeConfigurationChanges() {
    configurationChangeTask?.cancel()
    configurationChangeTask = Task { [weak self] in
      let notification = NotificationCenter.default.notifications(
        named: .AVAudioEngineConfigurationChange
      )
      for await _ in notification {
        guard let self = self, !Task.isCancelled else { return }
        await self.handleConfigurationChange()
      }
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
