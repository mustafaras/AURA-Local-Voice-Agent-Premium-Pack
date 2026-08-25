import AVFoundation
import AuraCore
import Foundation

extension ChatterboxTTSEngine {
  public func start() async throws(AuraError) -> TTSHealth {
    let fallbackHealth = try await fallback.start()
    guard fallbackHealth.ready else {
      let health = TTSHealth(
        ready: false, status: "not-ready",
        detail: "Chatterbox and system fallback unavailable")
      healthBox.set(health, neuralReady: false)
      return health
    }

    if !allowInjectedHelper, let issue = configuration.validationIssue() {
      let health = TTSHealth(
        ready: true, status: "fallback",
        detail: "System fallback active; \(issue)")
      healthBox.set(health, neuralReady: false)
      return health
    }

    let warming = TTSHealth(
      ready: true, status: "warming",
      detail: "System fallback active while Chatterbox V3 warms locally")
    healthBox.set(warming, neuralReady: false)
    Task { [weak self] in
      await self?.warmHelper()
    }
    return warming
  }

  public func speak(_ prompt: TTSPrompt) -> AsyncStream<TTSChunk> {
    AsyncStream { continuation in
      let box = ChatterboxContinuationBox(continuation: continuation)
      let task = Task { [weak self] in
        guard let self else {
          box.finish()
          return
        }
        await self.runSpeech(prompt, box: box)
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  private func runSpeech(_ prompt: TTSPrompt, box: ChatterboxContinuationBox) async {
    guard healthBox.neuralReady else {
      await streamFallback(prompt, box: box)
      return
    }
    guard await reserveNeuralTTS() else {
      await streamFallback(prompt, box: box)
      return
    }
    do {
      try await synthesizeNeural(prompt, box: box)
      await resourceGovernor?.release(.ttsNeural, estimatedMemoryMB: 1_536)
    } catch {
      await resourceGovernor?.release(.ttsNeural, estimatedMemoryMB: 1_536)
      await resourceGovernor?.recordFailure(.ttsNeural)
      await helper.stop()
      healthBox.set(
        TTSHealth(
          ready: true, status: "fallback",
          detail: "Chatterbox failed; system fallback active"),
        neuralReady: false)
      await streamFallback(prompt, box: box)
    }
  }

  private func reserveNeuralTTS() async -> Bool {
    let reservation = await resourceGovernor?.reserve(
      .ttsNeural, estimatedMemoryMB: 1_536, priority: .speech)
    guard reservation?.granted ?? true else {
      healthBox.set(
        TTSHealth(
          ready: true, status: "fallback",
          detail: "Neural TTS deferred by resource governor; system fallback active"),
        neuralReady: false)
      return false
    }
    return true
  }

  private func synthesizeNeural(
    _ prompt: TTSPrompt,
    box: ChatterboxContinuationBox
  ) async throws {
    let request = try makeRequest(prompt: prompt)
    let result = try await synthesizeWithTimeout(request)
    let audioURL = try validateAudioResult(result)
    box.yield(.progress(fragment: prompt.text, byteOffset: UInt64(result.frames)))
    defer { removePrivateAudioIfSafe(audioURL) }
    try await playback.play(audioURL)
    removePrivateAudioIfSafe(audioURL)
    box.yield(.complete)
    box.finish()
  }

  private func streamFallback(_ prompt: TTSPrompt, box: ChatterboxContinuationBox) async {
    for await chunk in fallback.speak(prompt) {
      box.yield(chunk)
    }
    box.finish()
  }

  public func stopSpeaking() async {
    await playback.stop()
    await helper.stop()
    await fallback.stopSpeaking()
    if configuration.validationIssue() == nil || allowInjectedHelper {
      healthBox.set(
        TTSHealth(
          ready: true, status: "stopped",
          detail: "Chatterbox stopped; system fallback remains available"),
        neuralReady: false)
      Task { [weak self] in
        await self?.warmHelper()
      }
    }
  }

  public func pauseSpeaking() async {
    await playback.pause()
    await fallback.pauseSpeaking()
  }

  public func resumeSpeaking() async {
    await playback.resume()
    await fallback.resumeSpeaking()
  }

  public func health() -> TTSHealth {
    healthBox.health
  }

  func warmHelper() async {
    do {
      let ready = try await helper.start()
      healthBox.set(
        TTSHealth(
          ready: true, status: "ready",
          detail:
            "Chatterbox Multilingual V3 ready locally on \(ready.device); "
            + "female reference configured"
        ),
        neuralReady: ready.referenceConfigured)
    } catch {
      healthBox.set(
        TTSHealth(
          ready: true, status: "fallback",
          detail: "Chatterbox warm-up failed; system fallback active"),
        neuralReady: false)
    }
  }

  func makeRequest(prompt: TTSPrompt) throws(AuraError) -> ChatterboxSynthesisRequest {
    let text = prompt.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text.count <= configuration.maxTextCharacters else {
      throw AuraError.ttsAdapterFailed(
        "Chatterbox text length must be 1...\(configuration.maxTextCharacters)")
    }
    let language = prompt.locale.lowercased().hasPrefix("en") ? "en" : "tr"
    return ChatterboxSynthesisRequest(
      id: UUID(), text: text, language: language,
      emphasis: min(max(prompt.emphasis, 0), 1))
  }

  func synthesizeWithTimeout(
    _ request: ChatterboxSynthesisRequest
  ) async throws -> ChatterboxSynthesisResult {
    try await withThrowingTaskGroup(of: ChatterboxSynthesisResult.self) { group in
      group.addTask { [helper] in
        try await helper.synthesize(request)
      }
      group.addTask { [timeout = configuration.helperTimeoutSeconds] in
        try await Task.sleep(for: .seconds(timeout))
        throw AuraError.ttsAdapterFailed("Chatterbox helper synthesis timed out")
      }
      defer { group.cancelAll() }
      guard let result = try await group.next() else {
        throw AuraError.ttsAdapterFailed("Chatterbox helper returned no result")
      }
      return result
    }
  }

  func validateAudioResult(_ result: ChatterboxSynthesisResult) throws(AuraError) -> URL {
    guard let outputDirectory = configuration.outputDirectory else {
      throw AuraError.ttsAdapterFailed("Chatterbox output directory missing")
    }
    let root = URL(fileURLWithPath: outputDirectory, isDirectory: true)
      .standardizedFileURL.resolvingSymlinksInPath()
    let file = URL(fileURLWithPath: result.path)
      .standardizedFileURL.resolvingSymlinksInPath()
    guard
      file.path.hasPrefix(root.path + "/"),
      file.pathExtension.lowercased() == "wav"
    else {
      throw AuraError.ttsAdapterFailed("Chatterbox returned an invalid audio path")
    }

    let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
    guard
      let type = attributes?[.type] as? FileAttributeType,
      type == .typeRegular,
      let size = attributes?[.size] as? NSNumber,
      size.intValue > 44,
      size.intValue <= configuration.maxAudioBytes
    else {
      throw AuraError.ttsAdapterFailed("Chatterbox audio artifact failed validation")
    }
    return file
  }

  func removePrivateAudioIfSafe(_ url: URL) {
    guard let outputDirectory = configuration.outputDirectory else { return }
    let root = URL(fileURLWithPath: outputDirectory, isDirectory: true)
      .standardizedFileURL.resolvingSymlinksInPath()
    let file = url.standardizedFileURL.resolvingSymlinksInPath()
    guard file.path.hasPrefix(root.path + "/") else { return }
    try? FileManager.default.removeItem(at: file)
  }
}
