import AuraCore
import Foundation
import Testing

@testable import AuraAudio

@Suite("Chatterbox TTS Engine")
struct ChatterboxTTSEngineTests {
  @Test func unconfiguredRuntimeUsesFemaleSystemFallbackContract() async throws {
    let fallback = MockTTSEngine()
    let engine = ChatterboxTTSEngine(fallback: fallback)

    let health = try await engine.start()
    #expect(health.ready)
    #expect(health.status == "fallback")
    #expect(health.detail.contains("Yelda"))

    let chunks = await engine.speak(
      TTSPrompt(text: "Merhaba dünya", locale: "tr-TR")
    ).reduce(into: [TTSChunk]()) { $0.append($1) }
    #expect(chunks.contains(.progress(fragment: "Merhaba", byteOffset: 7)))
    #expect(chunks.last == .complete)
  }

  @Test func configuredHelperWarmsAndSynthesizesLocally() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let helper = FakeChatterboxHelper(outputDirectory: directory)
    let playback = FakeChatterboxPlayback()
    let engine = ChatterboxTTSEngine(
      configuration: testConfiguration(outputDirectory: directory),
      helper: helper,
      fallback: MockTTSEngine(),
      playback: playback)

    let initial = try await engine.start()
    #expect(initial.status == "warming")
    try await waitUntilReady(engine)

    let chunks = await engine.speak(
      TTSPrompt(text: "İnce bir zekâ, yerinde bir cevap.", locale: "tr-TR")
    ).reduce(into: [TTSChunk]()) { $0.append($1) }

    #expect(chunks.last == .complete)
    #expect(await helper.requestCount() == 1)
    #expect(await playback.playCount() == 1)
    let remaining = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil)
    #expect(remaining.isEmpty)
  }

  @Test func helperCannotEscapePrivateOutputDirectory() async throws {
    let directory = try makeTemporaryDirectory()
    let escaped = directory.deletingLastPathComponent().appendingPathComponent("escape.wav")
    try Data(repeating: 0, count: 64).write(to: escaped)
    defer {
      try? FileManager.default.removeItem(at: directory)
      try? FileManager.default.removeItem(at: escaped)
    }

    let helper = FakeChatterboxHelper(outputDirectory: directory, resultURL: escaped)
    let playback = FakeChatterboxPlayback()
    let engine = ChatterboxTTSEngine(
      configuration: testConfiguration(outputDirectory: directory),
      helper: helper,
      fallback: MockTTSEngine(),
      playback: playback)
    _ = try await engine.start()
    try await waitUntilReady(engine)

    let chunks = await engine.speak(
      TTSPrompt(text: "Güvenli kal.", locale: "tr-TR")
    ).reduce(into: [TTSChunk]()) { $0.append($1) }

    #expect(chunks.last == .complete)
    #expect(await playback.playCount() == 0)
    #expect(engine.health().status == "fallback")
    #expect(FileManager.default.fileExists(atPath: escaped.path))
  }

  @Test func promptLengthIsBoundedBeforeHelperInvocation() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let helper = FakeChatterboxHelper(outputDirectory: directory)
    let engine = ChatterboxTTSEngine(
      configuration: testConfiguration(outputDirectory: directory, maxTextCharacters: 8),
      helper: helper,
      fallback: MockTTSEngine(),
      playback: FakeChatterboxPlayback())
    _ = try await engine.start()
    try await waitUntilReady(engine)

    let chunks = await engine.speak(
      TTSPrompt(text: "Bu metin sınırdan uzundur", locale: "tr-TR")
    ).reduce(into: [TTSChunk]()) { $0.append($1) }

    #expect(chunks.last == .complete)
    #expect(await helper.requestCount() == 0)
    #expect(engine.health().status == "fallback")
  }

  @Test func stopTerminatesHelperAndKeepsFallbackReady() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let helper = FakeChatterboxHelper(outputDirectory: directory)
    let engine = ChatterboxTTSEngine(
      configuration: testConfiguration(outputDirectory: directory),
      helper: helper,
      fallback: MockTTSEngine(),
      playback: FakeChatterboxPlayback())
    _ = try await engine.start()
    try await waitUntilReady(engine)

    await engine.stopSpeaking()

    #expect(await helper.stopCount() == 1)
    #expect(engine.health().ready)
  }

  @Test func helperTimeoutFallsBackAndStopsTheHelper() async throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let helper = HangingChatterboxHelper()
    let engine = ChatterboxTTSEngine(
      configuration: testConfiguration(
        outputDirectory: directory, helperTimeoutSeconds: 0.01),
      helper: helper,
      fallback: MockTTSEngine(),
      playback: FakeChatterboxPlayback())
    _ = try await engine.start()
    try await waitUntilReady(engine)

    let chunks = await engine.speak(
      TTSPrompt(text: "Zaman aşımı sonrası Yelda.", locale: "tr-TR")
    ).reduce(into: [TTSChunk]()) { $0.append($1) }

    #expect(chunks.last == .complete)
    #expect(await helper.stopCount() >= 1)
    #expect(engine.health().status == "fallback")
  }

  @Test func runtimeConfigurationFailsClosedAtEveryMaterialBoundary() throws {
    let directory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let helper = directory.appendingPathComponent("helper.py")
    let reference = directory.appendingPathComponent("reference.wav")
    try Data("# helper".utf8).write(to: helper)
    try Data(repeating: 0, count: 64).write(to: reference)

    let valid = ChatterboxTTSEngine.Configuration(
      pythonPath: "/bin/sh",
      helperScriptPath: helper.path,
      modelPath: directory.path,
      referenceAudioPath: reference.path,
      outputDirectory: directory.appendingPathComponent("output").path)
    #expect(valid.validationIssue() == nil)

    var changed = valid
    changed.device = "cuda"
    #expect(changed.validationIssue() == "unsupported device")
    changed = valid
    changed.maxAudioBytes = 44
    #expect(changed.validationIssue() == "invalid safety bounds")
    changed = valid
    changed.pythonPath = "/missing/python"
    #expect(changed.validationIssue() == "Python 3.11 runtime unavailable")
    changed = valid
    changed.helperScriptPath = "/missing/helper"
    #expect(changed.validationIssue() == "helper script unavailable")
    changed = valid
    changed.modelPath = "/missing/model"
    #expect(changed.validationIssue() == "V3 model snapshot unavailable")
    changed = valid
    changed.referenceAudioPath = "/missing/reference.wav"
    #expect(changed.validationIssue() == "owned female reference WAV unavailable")
    changed = valid
    changed.outputDirectory = nil
    #expect(changed.validationIssue() == "output directory unavailable")
  }

  private func testConfiguration(
    outputDirectory: URL,
    maxTextCharacters: Int = 2_000,
    helperTimeoutSeconds: Double = 45
  ) -> ChatterboxTTSEngine.Configuration {
    .init(
      pythonPath: "/test/python",
      helperScriptPath: "/test/helper.py",
      modelPath: "/test/model",
      referenceAudioPath: "/test/reference.wav",
      outputDirectory: outputDirectory.path,
      maxTextCharacters: maxTextCharacters,
      helperTimeoutSeconds: helperTimeoutSeconds)
  }

  private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("aura-chatterbox-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func waitUntilReady(_ engine: ChatterboxTTSEngine) async throws {
    for _ in 0..<100 {
      if engine.health().status == "ready" { return }
      try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Chatterbox helper did not become ready")
  }
}

private actor FakeChatterboxHelper: ChatterboxHelperExecuting {
  private let outputDirectory: URL
  private let resultURL: URL?
  private var requests = 0
  private var stops = 0

  init(outputDirectory: URL, resultURL: URL? = nil) {
    self.outputDirectory = outputDirectory
    self.resultURL = resultURL
  }

  func start() async throws -> ChatterboxHelperReady {
    ChatterboxHelperReady(device: "cpu-test", referenceConfigured: true)
  }

  func synthesize(_ request: ChatterboxSynthesisRequest) async throws
    -> ChatterboxSynthesisResult
  {
    requests += 1
    let url = resultURL ?? outputDirectory.appendingPathComponent("\(request.id).wav")
    try Data(repeating: 0, count: 64).write(to: url)
    return ChatterboxSynthesisResult(
      id: request.id,
      path: url.path,
      sampleRate: 24_000,
      frames: 240,
      synthesisMilliseconds: 10)
  }

  func stop() async {
    stops += 1
  }

  func requestCount() -> Int { requests }
  func stopCount() -> Int { stops }
}

private actor HangingChatterboxHelper: ChatterboxHelperExecuting {
  private var stops = 0

  func start() async throws -> ChatterboxHelperReady {
    ChatterboxHelperReady(device: "cpu-test", referenceConfigured: true)
  }

  func synthesize(_ request: ChatterboxSynthesisRequest) async throws
    -> ChatterboxSynthesisResult
  {
    try await Task.sleep(for: .seconds(10))
    throw AuraError.ttsAdapterFailed("unexpected test helper completion")
  }

  func stop() async {
    stops += 1
  }

  func stopCount() -> Int { stops }
}

private actor FakeChatterboxPlayback: ChatterboxAudioPlaying {
  private var plays = 0

  func play(_ url: URL) async throws(AuraError) {
    plays += 1
  }

  func stop() async {}
  func pause() async {}
  func resume() async {}
  func playCount() -> Int { plays }
}
