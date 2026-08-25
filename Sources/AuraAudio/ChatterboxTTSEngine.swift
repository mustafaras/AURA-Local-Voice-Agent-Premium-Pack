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

  let configuration: Configuration
  let helper: any ChatterboxHelperExecuting
  let fallback: any TTSEngine
  let playback: any ChatterboxAudioPlaying
  let resourceGovernor: VoiceResourceGovernor?
  let healthBox = ChatterboxHealthBox()
  let allowInjectedHelper: Bool

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
        preferredVoiceIdentifier: "com.apple.ttsbundle.gryphon-neural_Kaan_tr-TR_premium")
    self.allowInjectedHelper = false
  }

  init(
    configuration: Configuration,
    helper: any ChatterboxHelperExecuting,
    fallback: any TTSEngine,
    playback: any ChatterboxAudioPlaying,
    resourceGovernor: VoiceResourceGovernor? = nil
  ) {
    self.configuration = configuration
    self.helper = helper
    self.playback = playback
    self.resourceGovernor = resourceGovernor
    self.fallback = fallback
    self.allowInjectedHelper = true
  }

}
