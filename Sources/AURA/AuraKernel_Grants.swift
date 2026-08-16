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
  func seedDefaultGrants(_ policyEngine: PolicyEngine) async throws(AuraError) {
    // The list lives in `DefaultPolicyGrants` (AuraPolicy) so the production
    // default posture is unit-testable; this executable target cannot be
    // imported by test bundles. SP-006 added the filesystem/URL grants.
    //
    // Reconcile, never append. Issuing in a loop re-added the whole set on
    // every launch (a live run found 895 persisted grants) and, worse, left
    // pre-scoping `.any` grants in place where `matchingGrant` reaches them
    // first — so the SP-006 follow-up's target scoping was inert on any store
    // that had already run an older build.
    let pruned = try await policyEngine.reconcileSeededGrants(
      DefaultPolicyGrants.all, marker: DefaultPolicyGrants.seedPurpose)
    if pruned > 0 {
      await logger.info(
        "Policy grant migration pruned \(pruned) superseded seeded grant(s)", actor: .system)
    }
  }

  /// Build the configured TTS engine chain. Chatterbox V3 runs in a separate,
  /// local helper and owns a female system fallback, so warm-up or runtime
  /// failure never leaves the conversation voiceless.
  static func makeTTSEngine(
    adapterChain: TTSAdapterChain,
    preferredSystemVoiceIdentifier: String,
    logger: AuraLogger,
    governor: VoiceResourceGovernor? = nil
  ) async -> any TTSEngine {
    for adapterID in adapterChain.adapterIDs {
      if let engine = await tryStartTTSAdapter(
        adapterID,
        preferredSystemVoiceIdentifier: preferredSystemVoiceIdentifier,
        logger: logger,
        governor: governor)
      {
        return engine
      }
    }
    // Fail-closed fallback: system TTS must always be available on macOS.
    await logger.warning(
      "All configured TTS adapters unavailable; falling back to system", actor: .audio)
    let fallback = SystemTTSEngine(
      preferredVoiceIdentifier: preferredSystemVoiceIdentifier)
    do {
      _ = try await fallback.start()
    } catch {
      await logger.error("System TTS fallback failed: \(error)", actor: .audio)
    }
    return fallback
  }

  private static func tryStartTTSAdapter(
    _ adapterID: String,
    preferredSystemVoiceIdentifier: String,
    logger: AuraLogger,
    governor: VoiceResourceGovernor?
  ) async -> (any TTSEngine)? {
    switch adapterID {
    case "chatterbox":
      let helperScriptPath = Bundle.main.resourceURL?
        .appendingPathComponent("Chatterbox/chatterbox_helper.py").path
      let fallback = SystemTTSEngine(preferredVoiceIdentifier: preferredSystemVoiceIdentifier)
      let engine = ChatterboxTTSEngine(
        configuration: .installed(helperScriptPath: helperScriptPath),
        fallback: fallback, resourceGovernor: governor)
      do {
        let health = try await engine.start()
        if health.ready {
          await logger.info("TTS adapter ready: \(engine.engineID)", actor: .audio)
          return engine
        }
        await logger.info("TTS adapter \(adapterID) not ready; trying next", actor: .audio)
      } catch {
        await logger.warning("TTS adapter \(adapterID) failed: \(error)", actor: .audio)
      }
    case "system":
      let engine = SystemTTSEngine(preferredVoiceIdentifier: preferredSystemVoiceIdentifier)
      do {
        let health = try await engine.start()
        if health.ready {
          await logger.info("TTS adapter ready: \(engine.engineID)", actor: .audio)
          return engine
        }
      } catch {
        await logger.warning("TTS adapter \(adapterID) failed: \(error)", actor: .audio)
      }
    case "mock":
      let engine = MockTTSEngine()
      do {
        if try await engine.start().ready { return engine }
      } catch {
        await logger.warning("TTS adapter \(adapterID) failed: \(error)", actor: .audio)
      }
    default:
      await logger.warning("TTS adapter \(adapterID) not implemented; skipping", actor: .audio)
    }
    return nil
  }

  /// Build the configured STT engine. Supports `native-speech` for on-device
  /// `Speech.framework` streaming recognition, `mock-stt` for deterministic
  /// tests, and the legacy placeholder as a final fallback. The locale and
  /// vocabulary are taken from `STTConfiguration`.
  static func makeSTTEngine(
    configuration: STTConfiguration,
    vocabulary: UserVocabulary,
    governor: VoiceResourceGovernor? = nil
  ) -> any STTEngine {
    switch configuration.engineID {
    case "native-speech":
      return STTRouter(
        candidates: [
          SystemSTTEngine(
            locale: Locale(identifier: configuration.locale),
            vocabulary: vocabulary,
            enableCustomVocabulary: configuration.enableCustomVocabulary),
          SystemSTTEngine(
            engineID: "native-speech-fallback",
            locale: Locale(identifier: configuration.fallbackLocale),
            vocabulary: vocabulary,
            enableCustomVocabulary: configuration.enableCustomVocabulary),
        ],
        governor: governor)
    case "native-speech-single":
      return SystemSTTEngine(
        locale: Locale(identifier: configuration.locale),
        vocabulary: vocabulary,
        enableCustomVocabulary: configuration.enableCustomVocabulary)
    case "mock-stt":
      return DeterministicMockSTTEngine(
        engineID: "mock-stt",
        locale: Locale(identifier: configuration.locale),
        script: [
          DeterministicMockSTTEngine.MockSegment(text: "hello", expectedFrameCount: 1)
        ])
    default:
      return DeterministicMockSTTEngine(
        engineID: "fallback-mock-stt",
        locale: Locale(identifier: configuration.locale),
        script: [
          DeterministicMockSTTEngine.MockSegment(text: "hello", expectedFrameCount: 1)
        ])
    }
  }
}
