import AVFoundation
import AuraCore
import Foundation

/// A local Chatterbox Multilingual V3 adapter with a female system fallback.
///
/// Neural inference runs in a separately spawned Python process. Prompt text
/// is sent as bounded JSON over stdin, never argv or a network endpoint. The
/// helper writes a private WAV under AURA Application Support; this adapter
/// validates, plays, and removes that artifact.
public final class ChatterboxTTSEngine: TTSEngine, @unchecked Sendable {
  public let engineID = "chatterbox"

  public struct Configuration: Sendable, Equatable {
    public var pythonPath: String?
    public var helperScriptPath: String?
    public var modelPath: String?
    public var referenceAudioPath: String?
    public var outputDirectory: String?
    public var device: String
    public var maxTextCharacters: Int
    public var maxAudioBytes: Int
    public var helperTimeoutSeconds: Double

    public init(
      pythonPath: String? = nil,
      helperScriptPath: String? = nil,
      modelPath: String? = nil,
      referenceAudioPath: String? = nil,
      outputDirectory: String? = nil,
      // CPU is the qualified safe default on the supported 16 GB profile.
      // MPS remains opt-in until a live latency/thermal qualification exists.
      device: String = "cpu",
      maxTextCharacters: Int = 2_000,
      maxAudioBytes: Int = 32 * 1_024 * 1_024,
      helperTimeoutSeconds: Double = 45
    ) {
      self.pythonPath = pythonPath
      self.helperScriptPath = helperScriptPath
      self.modelPath = modelPath
      self.referenceAudioPath = referenceAudioPath
      self.outputDirectory = outputDirectory
      self.device = device
      self.maxTextCharacters = maxTextCharacters
      self.maxAudioBytes = maxAudioBytes
      self.helperTimeoutSeconds = helperTimeoutSeconds
    }

    /// Resolve the user-controlled local runtime without embedding weights.
    public static func installed(helperScriptPath: String?) -> Configuration {
      let support = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first?.appendingPathComponent("AURA", isDirectory: true)
      return Configuration(
        pythonPath: support?.appendingPathComponent(
          "Runtime/chatterbox/.venv/bin/python"
        ).path,
        helperScriptPath: helperScriptPath,
        modelPath: support?.appendingPathComponent(
          "Models/chatterbox-v3", isDirectory: true
        ).path,
        referenceAudioPath: support?.appendingPathComponent(
          "Voices/aura-female-reference.wav"
        ).path,
        outputDirectory: support?.appendingPathComponent(
          "Cache/chatterbox-audio", isDirectory: true
        ).path)
    }

    func validationIssue(fileManager: FileManager = .default) -> String? {
      guard device == "mps" || device == "cpu" else {
        return "unsupported device"
      }
      guard maxTextCharacters > 0, maxAudioBytes > 44, helperTimeoutSeconds > 0 else {
        return "invalid safety bounds"
      }
      guard let pythonPath, fileManager.isExecutableFile(atPath: pythonPath) else {
        return "Python 3.11 runtime unavailable"
      }
      guard let helperScriptPath, fileManager.isReadableFile(atPath: helperScriptPath) else {
        return "helper script unavailable"
      }
      guard let modelPath, isDirectory(modelPath, fileManager: fileManager) else {
        return "V3 model snapshot unavailable"
      }
      guard
        let referenceAudioPath,
        referenceAudioPath.lowercased().hasSuffix(".wav"),
        fileManager.isReadableFile(atPath: referenceAudioPath)
      else {
        return "owned female reference WAV unavailable"
      }
      guard let outputDirectory, !outputDirectory.isEmpty else {
        return "output directory unavailable"
      }
      return nil
    }

    private func isDirectory(_ path: String, fileManager: FileManager) -> Bool {
      var isDirectory: ObjCBool = false
      return fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        && isDirectory.boolValue
    }
  }

  private let configuration: Configuration
  private let helper: any ChatterboxHelperExecuting
  private let fallback: any TTSEngine
  private let playback: any ChatterboxAudioPlaying
  private let resourceGovernor: VoiceResourceGovernor?
  private let healthBox = ChatterboxHealthBox()
  private let allowInjectedHelper: Bool

  public init(
    configuration: Configuration = Configuration(),
    fallback: (any TTSEngine)? = nil,
    resourceGovernor: VoiceResourceGovernor? = nil
  ) {
    self.configuration = configuration
    self.helper = ProcessChatterboxHelper(configuration: configuration)
    self.playback = ChatterboxAudioPlayback()
    self.resourceGovernor = resourceGovernor
    self.fallback =
      fallback
      ?? SystemTTSEngine(
        preferredVoiceIdentifier: "com.apple.voice.compact.tr-TR.Yelda")
    self.allowInjectedHelper = false
  }

  init(
    configuration: Configuration,
    helper: any ChatterboxHelperExecuting,
    fallback: any TTSEngine,
    playback: any ChatterboxAudioPlaying = ChatterboxAudioPlayback(),
    resourceGovernor: VoiceResourceGovernor? = nil
  ) {
    self.configuration = configuration
    self.helper = helper
    self.playback = playback
    self.resourceGovernor = resourceGovernor
    self.fallback = fallback
    self.allowInjectedHelper = true
  }

  public func start() async throws(AuraError) -> TTSHealth {
    let fallbackHealth = try await fallback.start()
    guard fallbackHealth.ready else {
      let health = TTSHealth(
        ready: false, status: "not-ready",
        detail: "Chatterbox and female system fallback unavailable")
      healthBox.set(health, neuralReady: false)
      return health
    }

    if !allowInjectedHelper, let issue = configuration.validationIssue() {
      let health = TTSHealth(
        ready: true, status: "fallback",
        detail: "Female Yelda fallback active; \(issue)")
      healthBox.set(health, neuralReady: false)
      return health
    }

    let warming = TTSHealth(
      ready: true, status: "warming",
      detail: "Female Yelda active while Chatterbox V3 warms locally")
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

        if healthBox.neuralReady {
          let reservation = await resourceGovernor?.reserve(
            .ttsNeural, estimatedMemoryMB: 1_536, priority: .speech)
          guard reservation?.granted ?? true else {
            healthBox.set(
              TTSHealth(
                ready: true,
                status: "fallback",
                detail: "Neural TTS deferred by resource governor; female Yelda fallback active"),
              neuralReady: false)
            for await chunk in fallback.speak(prompt) {
              box.yield(chunk)
            }
            box.finish()
            return
          }
          do {
            let request = try makeRequest(prompt: prompt)
            let result = try await synthesizeWithTimeout(request)
            let audioURL = try validateAudioResult(result)
            box.yield(.progress(fragment: prompt.text, byteOffset: UInt64(result.frames)))
            defer { removePrivateAudioIfSafe(audioURL) }
            try await playback.play(audioURL)
            removePrivateAudioIfSafe(audioURL)
            await resourceGovernor?.release(.ttsNeural, estimatedMemoryMB: 1_536)
            box.yield(.complete)
            box.finish()
            return
          } catch {
            await resourceGovernor?.release(.ttsNeural, estimatedMemoryMB: 1_536)
            await resourceGovernor?.recordFailure(.ttsNeural)
            await helper.stop()
            healthBox.set(
              TTSHealth(
                ready: true, status: "fallback",
                detail: "Chatterbox failed; female Yelda fallback active"),
              neuralReady: false)
          }
        }

        for await chunk in fallback.speak(prompt) {
          box.yield(chunk)
        }
        box.finish()
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  public func stopSpeaking() async {
    await playback.stop()
    await helper.stop()
    await fallback.stopSpeaking()
    if configuration.validationIssue() == nil || allowInjectedHelper {
      healthBox.set(
        TTSHealth(
          ready: true, status: "stopped",
          detail: "Chatterbox stopped; female Yelda fallback remains available"),
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

  private func warmHelper() async {
    do {
      let ready = try await helper.start()
      healthBox.set(
        TTSHealth(
          ready: true, status: "ready",
          detail:
            "Chatterbox Multilingual V3 ready locally on \(ready.device); female reference configured"
        ),
        neuralReady: ready.referenceConfigured)
    } catch {
      healthBox.set(
        TTSHealth(
          ready: true, status: "fallback",
          detail: "Chatterbox warm-up failed; female Yelda fallback active"),
        neuralReady: false)
    }
  }

  private func makeRequest(prompt: TTSPrompt) throws(AuraError) -> ChatterboxSynthesisRequest {
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

  private func synthesizeWithTimeout(
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

  private func validateAudioResult(_ result: ChatterboxSynthesisResult) throws(AuraError) -> URL {
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

  private func removePrivateAudioIfSafe(_ url: URL) {
    guard let outputDirectory = configuration.outputDirectory else { return }
    let root = URL(fileURLWithPath: outputDirectory, isDirectory: true)
      .standardizedFileURL.resolvingSymlinksInPath()
    let file = url.standardizedFileURL.resolvingSymlinksInPath()
    guard file.path.hasPrefix(root.path + "/") else { return }
    try? FileManager.default.removeItem(at: file)
  }
}

struct ChatterboxHelperReady: Sendable, Equatable {
  let device: String
  let referenceConfigured: Bool
}

struct ChatterboxSynthesisRequest: Sendable, Equatable, Encodable {
  let command = "synthesize"
  let id: UUID
  let text: String
  let language: String
  let emphasis: Double
}

struct ChatterboxSynthesisResult: Sendable, Equatable {
  let id: UUID
  let path: String
  let sampleRate: Int
  let frames: Int
  let synthesisMilliseconds: Int
}

protocol ChatterboxHelperExecuting: Sendable {
  func start() async throws -> ChatterboxHelperReady
  func synthesize(_ request: ChatterboxSynthesisRequest) async throws
    -> ChatterboxSynthesisResult
  func stop() async
}

private actor ProcessChatterboxHelper: ChatterboxHelperExecuting {
  private struct Envelope: Decodable {
    let type: String
    let id: UUID?
    let path: String?
    let device: String?
    let referenceConfigured: Bool?
    let sampleRate: Int?
    let frames: Int?
    let synthesisMilliseconds: Int?
    let detail: String?

    enum CodingKeys: String, CodingKey {
      case type, id, path, device, frames, detail
      case referenceConfigured = "reference_configured"
      case sampleRate = "sample_rate"
      case synthesisMilliseconds = "synthesis_ms"
    }
  }

  private let configuration: ChatterboxTTSEngine.Configuration
  private var process: Process?
  private var input: FileHandle?
  private var readerTask: Task<Void, Never>?
  private var ready: ChatterboxHelperReady?
  private var readyWaiters: [CheckedContinuation<ChatterboxHelperReady, any Error>] = []
  private var pending: [UUID: CheckedContinuation<ChatterboxSynthesisResult, any Error>] = [:]

  init(configuration: ChatterboxTTSEngine.Configuration) {
    self.configuration = configuration
  }

  func start() async throws -> ChatterboxHelperReady {
    if let ready { return ready }
    if process == nil {
      try launch()
    }
    return try await withCheckedThrowingContinuation { continuation in
      readyWaiters.append(continuation)
    }
  }

  func synthesize(_ request: ChatterboxSynthesisRequest) async throws
    -> ChatterboxSynthesisResult
  {
    guard ready != nil, let input else {
      throw AuraError.ttsAdapterFailed("Chatterbox helper is not ready")
    }
    var encoded = try JSONEncoder().encode(request)
    guard encoded.count <= 16_383 else {
      throw AuraError.ttsAdapterFailed("Chatterbox request exceeds protocol limit")
    }
    encoded.append(0x0A)
    return try await withCheckedThrowingContinuation { continuation in
      pending[request.id] = continuation
      do {
        try input.write(contentsOf: encoded)
      } catch {
        pending.removeValue(forKey: request.id)
        continuation.resume(
          throwing: AuraError.ttsAdapterFailed("Chatterbox helper input failed"))
      }
    }
  }

  func stop() async {
    readerTask?.cancel()
    readerTask = nil
    try? input?.close()
    input = nil
    if let process, process.isRunning {
      process.terminate()
    }
    process = nil
    ready = nil
    failAll(detail: "Chatterbox helper stopped")
  }

  private func launch() throws {
    guard
      let pythonPath = configuration.pythonPath,
      let helperScriptPath = configuration.helperScriptPath,
      let modelPath = configuration.modelPath,
      let referenceAudioPath = configuration.referenceAudioPath,
      let outputDirectory = configuration.outputDirectory
    else {
      throw AuraError.ttsAdapterFailed("Chatterbox runtime configuration incomplete")
    }

    try FileManager.default.createDirectory(
      atPath: outputDirectory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])

    let process = Process()
    let standardInput = Pipe()
    let standardOutput = Pipe()
    process.executableURL = URL(fileURLWithPath: pythonPath)
    process.arguments = [
      helperScriptPath,
      "--model-dir", modelPath,
      "--output-dir", outputDirectory,
      "--reference-audio", referenceAudioPath,
      "--device", configuration.device,
    ]
    process.environment = [
      "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
      "PYTHONUNBUFFERED": "1",
      "HF_HUB_OFFLINE": "1",
      "TOKENIZERS_PARALLELISM": "false",
    ]
    process.standardInput = standardInput
    process.standardOutput = standardOutput
    process.standardError = FileHandle.nullDevice
    try process.run()

    self.process = process
    self.input = standardInput.fileHandleForWriting
    let output = standardOutput.fileHandleForReading
    readerTask = Task { [weak self] in
      do {
        for try await line in output.bytes.lines {
          await self?.handle(line: String(line))
        }
        await self?.helperEnded()
      } catch {
        await self?.helperEnded()
      }
    }
  }

  private func handle(line: String) {
    guard line.utf8.count <= 65_536,
      let data = line.data(using: .utf8),
      let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
    else {
      failAll(detail: "Chatterbox helper emitted invalid protocol data")
      return
    }

    switch envelope.type {
    case "ready":
      guard let device = envelope.device else {
        failAll(detail: "Chatterbox ready response incomplete")
        return
      }
      let ready = ChatterboxHelperReady(
        device: device,
        referenceConfigured: envelope.referenceConfigured == true)
      self.ready = ready
      let waiters = readyWaiters
      readyWaiters.removeAll()
      for waiter in waiters {
        waiter.resume(returning: ready)
      }
    case "result":
      guard
        let id = envelope.id,
        let path = envelope.path,
        let sampleRate = envelope.sampleRate,
        let frames = envelope.frames,
        let synthesisMilliseconds = envelope.synthesisMilliseconds,
        let continuation = pending.removeValue(forKey: id)
      else { return }
      continuation.resume(
        returning: ChatterboxSynthesisResult(
          id: id, path: path, sampleRate: sampleRate, frames: frames,
          synthesisMilliseconds: synthesisMilliseconds))
    case "error":
      guard let id = envelope.id, let continuation = pending.removeValue(forKey: id)
      else { return }
      continuation.resume(
        throwing: AuraError.ttsAdapterFailed(
          envelope.detail ?? "Chatterbox synthesis failed"))
    case "fatal":
      failAll(detail: envelope.detail ?? "Chatterbox helper failed")
    default:
      break
    }
  }

  private func helperEnded() {
    ready = nil
    process = nil
    input = nil
    failAll(detail: "Chatterbox helper exited")
  }

  private func failAll(detail: String) {
    let waiters = readyWaiters
    readyWaiters.removeAll()
    for waiter in waiters {
      waiter.resume(throwing: AuraError.ttsAdapterFailed(detail))
    }
    let requests = pending.values
    pending.removeAll()
    for request in requests {
      request.resume(throwing: AuraError.ttsAdapterFailed(detail))
    }
  }
}

protocol ChatterboxAudioPlaying: Sendable {
  func play(_ url: URL) async throws(AuraError)
  func stop() async
  func pause() async
  func resume() async
}

private actor ChatterboxAudioPlayback: ChatterboxAudioPlaying {
  private var player: AVAudioPlayer?

  func play(_ url: URL) async throws(AuraError) {
    let player: AVAudioPlayer
    do {
      player = try AVAudioPlayer(contentsOf: url)
    } catch {
      throw AuraError.ttsAdapterFailed("Chatterbox audio playback could not initialize")
    }
    self.player = player
    guard player.prepareToPlay(), player.play() else {
      self.player = nil
      throw AuraError.ttsAdapterFailed("Chatterbox audio playback could not start")
    }
    while player.isPlaying {
      if Task.isCancelled {
        player.stop()
        self.player = nil
        throw AuraError.ttsAdapterFailed("Chatterbox audio playback cancelled")
      }
      try? await Task.sleep(for: .milliseconds(20))
    }
    if self.player === player {
      self.player = nil
    }
  }

  func stop() {
    player?.stop()
    player = nil
  }

  func pause() {
    player?.pause()
  }

  func resume() {
    _ = player?.play()
  }
}

private final class ChatterboxHealthBox: @unchecked Sendable {
  private let lock = NSLock()
  private var storedHealth = TTSHealth(
    ready: false, status: "not-ready",
    detail: "Chatterbox has not started")
  private var storedNeuralReady = false

  var health: TTSHealth {
    lock.withLock { storedHealth }
  }

  var neuralReady: Bool {
    lock.withLock { storedNeuralReady }
  }

  func set(_ health: TTSHealth, neuralReady: Bool) {
    lock.withLock {
      storedHealth = health
      storedNeuralReady = neuralReady
    }
  }
}

private final class ChatterboxContinuationBox: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: AsyncStream<TTSChunk>.Continuation?

  init(continuation: AsyncStream<TTSChunk>.Continuation) {
    self.continuation = continuation
  }

  func yield(_ chunk: TTSChunk) {
    lock.withLock { continuation }?.yield(chunk)
  }

  func finish() {
    let continuation = lock.withLock {
      let current = self.continuation
      self.continuation = nil
      return current
    }
    continuation?.finish()
  }
}
