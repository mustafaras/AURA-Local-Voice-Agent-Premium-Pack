import AuraAudio
import AuraSTT
import Foundation
import Speech

// SP-016 bilingual STT quality probe.
//
// Why this exists as a bundled executable instead of a test:
// Speech Recognition authorization is granted per executable, and the SwiftPM
// test helper is a bare binary with no Info.plist — requesting authorization
// from it aborts the process (SIGABRT, exit 134) rather than prompting. This
// target is assembled into a signed .app bundle carrying
// NSSpeechRecognitionUsageDescription, so it can hold the grant and drive the
// real `SystemSTTEngine` over a synthesized bilingual corpus.
//
// It reads a microphone never. All audio originates from `say`.

/// The engine's native capture format. Frames are 100 ms at 16 kHz, matching
/// what `AuraAudio` delivers in production.
let sampleRate: Double = 16_000
let frameLength = 1_600
let frameDuration = Double(frameLength) / sampleRate

// MARK: - Report model

struct UtteranceResult: Codable {
  let utteranceID: String
  let band: String
  let localeID: String
  let condition: String
  /// Whether the recognizer was given contextual technical hints. This is the
  /// A/B arm: the production engine defaults `enableCustomVocabulary` to true,
  /// so measuring only the hint-less arm would misreport shipped behavior.
  let vocabularyHints: Bool
  let reference: String
  let hypothesis: String
  let wordErrorRate: Double
  let entityRecall: Double
  let missingEntities: [String]
  /// Activation to first stable segment, matching `STTPipeline.Metrics`.
  let turnEndLatencySeconds: Double
  /// End of audio to first stable segment: how long after the speaker stops
  /// the transcript is actionable. This is the number a user perceives.
  let finalizationLatencySeconds: Double
  let audioDurationSeconds: Double
  let recognized: Bool
  let failureDetail: String?
}

struct BandSummary: Codable {
  let band: String
  let condition: String
  let vocabularyHints: Bool
  let utteranceCount: Int
  let meanWordErrorRate: Double
  let meanEntityRecall: Double
  let meanTurnEndLatencySeconds: Double
  let meanFinalizationLatencySeconds: Double
}

struct ProbeReport: Codable {
  let evidenceID: String
  let generatedAt: String
  /// Deliberately the CPU architecture, not the machine name. A hostname is
  /// personally identifying and evidence records must not carry private data.
  let hostArchitecture: String
  let osVersion: String
  let onDeviceOnly: Bool
  let localeSupport: [String: String]
  let noisySNRdB: Double
  let farFieldGain: Double
  let results: [UtteranceResult]
  let bandSummaries: [BandSummary]
  let overallMeanWordErrorRate: Double
  let overallMeanEntityRecall: Double
  let overallMeanTurnEndLatencySeconds: Double
  let overallMeanFinalizationLatencySeconds: Double
  /// Headline A/B: quality with and without contextual technical hints.
  let armSummaries: [ArmSummary]
  let limitations: [String]
}

/// Aggregate for one vocabulary arm across the whole corpus.
struct ArmSummary: Codable {
  let vocabularyHints: Bool
  let meanWordErrorRate: Double
  let meanEntityRecall: Double
  let meanFinalizationLatencySeconds: Double
}

// MARK: - Authorization

func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
  let current = SFSpeechRecognizer.authorizationStatus()
  if current != .notDetermined { return current }
  return await withCheckedContinuation { continuation in
    SFSpeechRecognizer.requestAuthorization { status in
      continuation.resume(returning: status)
    }
  }
}

/// CPU architecture for the environment record. Never the hostname.
func currentArchitecture() -> String {
  #if arch(arm64)
    return "arm64"
  #elseif arch(x86_64)
    return "x86_64"
  #else
    return "unknown"
  #endif
}

func describe(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
  switch status {
  case .notDetermined: return "notDetermined"
  case .denied: return "denied"
  case .restricted: return "restricted"
  case .authorized: return "authorized"
  @unknown default: return "unknown(\(status.rawValue))"
  }
}

// MARK: - Recognition

/// Drive one conditioned utterance through the real engine and score it.
func evaluate(
  utterance: CorpusUtterance,
  condition: AcousticCondition,
  vocabularyHints: Bool,
  seed: UInt64
) async -> UtteranceResult {
  func failure(_ detail: String, audioDuration: Double = 0) -> UtteranceResult {
    UtteranceResult(
      utteranceID: utterance.id,
      band: utterance.band,
      localeID: utterance.localeID,
      condition: condition.rawValue,
      vocabularyHints: vocabularyHints,
      reference: utterance.reference,
      hypothesis: "",
      wordErrorRate: 1.0,
      entityRecall: 0.0,
      missingEntities: utterance.entities.map(\.canonical),
      turnEndLatencySeconds: 0,
      finalizationLatencySeconds: 0,
      audioDurationSeconds: audioDuration,
      recognized: false,
      failureDetail: detail)
  }

  let audioURL: URL
  do {
    audioURL = try AudioConditioning.synthesize(text: utterance.reference, voice: utterance.voice)
  } catch {
    return failure("synthesis: \(error)")
  }
  defer { try? FileManager.default.removeItem(at: audioURL) }

  let clean: [Float]
  do {
    clean = try AudioConditioning.decodeMonoFloatSamples(at: audioURL)
  } catch {
    return failure("decode: \(error)")
  }
  guard !clean.isEmpty else { return failure("decode: empty sample buffer") }

  let samples = AudioConditioning.apply(
    condition, to: clean, sampleRate: sampleRate, seed: seed)
  let audioDuration = Double(samples.count) / sampleRate

  // The vocabulary arm mirrors production: `enableCustomVocabulary` defaults
  // to true in `SystemSTTEngine`, and the hints are the corpus's technical
  // terms plus the shipped bilingual vocabulary.
  var vocabulary = UserVocabulary.bilingualTestVocabulary
  vocabulary.technicalTerms.formUnion(Corpus.technicalHints)

  let engine = SystemSTTEngine(
    engineID: "sp016-probe",
    locale: Locale(identifier: utterance.localeID),
    vocabulary: vocabularyHints ? vocabulary : nil,
    enableCustomVocabulary: vocabularyHints)

  do {
    _ = try await engine.start()
  } catch {
    return failure("engine start: \(error)", audioDuration: audioDuration)
  }

  let activation = Date()
  let collector = Task { () -> (String, Date?) in
    var latest = ""
    var stableAt: Date?
    for await result in engine.results {
      if !result.text.isEmpty { latest = result.text }
      if result.isStable {
        stableAt = Date()
        break
      }
    }
    return (latest, stableAt)
  }

  // Ingest in real time. Pushing every frame as fast as the loop can run makes
  // turn-end latency meaningless — it would measure how fast the machine can
  // shovel buffers, not how long a speaker waits. Pacing at the frame duration
  // reproduces the live cadence the pipeline actually sees.
  var index: UInt64 = 0
  for start in stride(from: 0, to: samples.count, by: frameLength) {
    let end = min(start + frameLength, samples.count)
    await engine.ingest(
      AudioFrame(
        samples: Array(samples[start..<end]),
        timestamp: Double(index) * frameDuration,
        sequenceIndex: index),
      activationTime: 0)
    index += 1
    try? await Task.sleep(nanoseconds: UInt64(frameDuration * 1_000_000_000))
  }
  let audioEnded = Date()
  await engine.finalizeSession()

  // Bound the wait so a recognizer that never finalizes fails the utterance
  // instead of hanging the whole probe.
  let deadline = Task {
    try? await Task.sleep(nanoseconds: 25_000_000_000)
    collector.cancel()
  }
  let (transcript, stableAt) = await collector.value
  deadline.cancel()
  await engine.cancel()

  let stableTime = stableAt ?? Date()
  return UtteranceResult(
    utteranceID: utterance.id,
    band: utterance.band,
    localeID: utterance.localeID,
    condition: condition.rawValue,
    vocabularyHints: vocabularyHints,
    reference: utterance.reference,
    hypothesis: transcript,
    wordErrorRate: Metrics.wordErrorRate(reference: utterance.reference, hypothesis: transcript),
    entityRecall: Metrics.entityRecall(entities: utterance.entities, hypothesis: transcript),
    missingEntities: Metrics.missingEntities(
      entities: utterance.entities, hypothesis: transcript),
    turnEndLatencySeconds: stableTime.timeIntervalSince(activation),
    finalizationLatencySeconds: max(0, stableTime.timeIntervalSince(audioEnded)),
    audioDurationSeconds: audioDuration,
    recognized: !transcript.isEmpty,
    failureDetail: transcript.isEmpty ? "no transcript produced" : nil)
}

// MARK: - Entry point

// Launched through LaunchServices (`open`) so TCC attributes the Speech
// request to this bundle rather than to the invoking terminal. LaunchServices
// does not forward the caller's environment, so the destination is accepted as
// an argument first and only falls back to the environment when run directly.
let outputPath =
  CommandLine.arguments.dropFirst().first
  ?? ProcessInfo.processInfo.environment["AURA_PROBE_OUTPUT"]
  ?? "/tmp/aura-sp016-speech-probe.json"

func writeFailure(_ message: String) {
  let payload = ["error": message]
  if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
    try? data.write(to: URL(fileURLWithPath: outputPath))
  }
  FileHandle.standardError.write(Data("SP016-PROBE-ERROR: \(message)\n".utf8))
}

let status = await requestSpeechAuthorization()
guard status == .authorized else {
  writeFailure("speech recognition not authorized: \(describe(status))")
  exit(2)
}

// Record which locales actually support on-device recognition. If a locale
// does not, that is a truthful capability limit and must appear in the report
// rather than being silently skipped.
var localeSupport: [String: String] = [:]
for localeID in Set(Corpus.utterances.map(\.localeID)).sorted() {
  let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
  guard let recognizer else {
    localeSupport[localeID] = "no recognizer"
    continue
  }
  localeSupport[localeID] =
    "available=\(recognizer.isAvailable) onDevice=\(recognizer.supportsOnDeviceRecognition)"
}

var results: [UtteranceResult] = []
var seed: UInt64 = 0x5150_1600_0000_0001
for utterance in Corpus.utterances {
  for condition in AcousticCondition.allCases {
    seed = seed &+ 0x9E37_79B9_7F4A_7C15
    // Both arms see the identical noise realization, so an arm-to-arm delta is
    // attributable to the vocabulary hints and not to a different dice roll.
    for vocabularyHints in [false, true] {
      let result = await evaluate(
        utterance: utterance, condition: condition,
        vocabularyHints: vocabularyHints, seed: seed)
      results.append(result)
      let progress =
        "\(result.utteranceID)/\(result.condition)/hints=\(vocabularyHints): "
        + "WER=\(String(format: "%.3f", result.wordErrorRate)) "
        + "entity=\(String(format: "%.2f", result.entityRecall)) "
        + "final=\(String(format: "%.2f", result.finalizationLatencySeconds))s\n"
      FileHandle.standardError.write(Data(progress.utf8))
    }
  }
}

func mean(_ values: [Double]) -> Double {
  guard !values.isEmpty else { return 0 }
  return values.reduce(0, +) / Double(values.count)
}

var summaries: [BandSummary] = []
for band in Set(results.map(\.band)).sorted() {
  for condition in AcousticCondition.allCases {
    for vocabularyHints in [false, true] {
      let slice = results.filter {
        $0.band == band && $0.condition == condition.rawValue
          && $0.vocabularyHints == vocabularyHints
      }
      guard !slice.isEmpty else { continue }
      summaries.append(
        BandSummary(
          band: band,
          condition: condition.rawValue,
          vocabularyHints: vocabularyHints,
          utteranceCount: slice.count,
          meanWordErrorRate: mean(slice.map(\.wordErrorRate)),
          meanEntityRecall: mean(slice.map(\.entityRecall)),
          meanTurnEndLatencySeconds: mean(slice.map(\.turnEndLatencySeconds)),
          meanFinalizationLatencySeconds: mean(slice.map(\.finalizationLatencySeconds))))
    }
  }
}

let formatter = ISO8601DateFormatter()
let report = ProbeReport(
  evidenceID: "EV-SP-016-BILINGUAL-QUALITY",
  generatedAt: formatter.string(from: Date()),
  hostArchitecture: currentArchitecture(),
  osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
  onDeviceOnly: true,
  localeSupport: localeSupport,
  noisySNRdB: AudioConditioning.noisySNRdB,
  farFieldGain: Double(AudioConditioning.farFieldGain),
  results: results,
  bandSummaries: summaries,
  overallMeanWordErrorRate: mean(results.map(\.wordErrorRate)),
  overallMeanEntityRecall: mean(results.map(\.entityRecall)),
  overallMeanTurnEndLatencySeconds: mean(results.map(\.turnEndLatencySeconds)),
  overallMeanFinalizationLatencySeconds: mean(results.map(\.finalizationLatencySeconds)),
  armSummaries: [false, true].map { hints in
    let slice = results.filter { $0.vocabularyHints == hints }
    return ArmSummary(
      vocabularyHints: hints,
      meanWordErrorRate: mean(slice.map(\.wordErrorRate)),
      meanEntityRecall: mean(slice.map(\.entityRecall)),
      meanFinalizationLatencySeconds: mean(slice.map(\.finalizationLatencySeconds)))
  },
  limitations: [
    "Audio is synthesized with system voices (say), not spoken by a human.",
    "No accent variation, disfluency, or speaker diversity is represented.",
    "Noisy and far-field bands are simulated (AWGN at fixed SNR; attenuation "
      + "plus a single reflection and low-pass), not recorded in a real room.",
    "The microphone capture path is not exercised; audio is injected as frames.",
    "Measured quality is therefore an optimistic bound on live user quality.",
    "Audio is paced at real time on ingest, so turn-end and finalization "
      + "latency are comparable to a live turn, but no microphone, echo path, "
      + "or acoustic barge-in is involved.",
  ])

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
do {
  let data = try encoder.encode(report)
  try data.write(to: URL(fileURLWithPath: outputPath))
  FileHandle.standardError.write(Data("SP016-PROBE-OK: wrote \(outputPath)\n".utf8))
} catch {
  writeFailure("report write failed: \(error)")
  exit(3)
}
exit(0)
