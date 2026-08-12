import AVFoundation
import AuraCore
import Foundation

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

private struct ChatterboxHelperEnvelope: Decodable {
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

actor ProcessChatterboxHelper: ChatterboxHelperExecuting {
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
      let envelope = try? JSONDecoder().decode(ChatterboxHelperEnvelope.self, from: data)
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

actor ChatterboxAudioPlayback: ChatterboxAudioPlaying {
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

final class ChatterboxHealthBox: @unchecked Sendable {
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

final class ChatterboxContinuationBox: @unchecked Sendable {
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
