import AuraConfig
import AuraCore
import AuraStore
import Foundation
import Testing

// MARK: - Attack taxonomy: configuration non-weakening / kill-switch / expiry fail-closed

private let maximumAllowByDefaultRisk = "policy.maximumAllowByDefaultRisk"
private let minimumConfirmationRisk = "policy.minimumConfirmationRisk"
private let modelsMaxConcurrentLocalModels = "models.maxConcurrentLocalModels"
private let privacyRawTelemetryEnabled = "privacy.rawTelemetryEnabled"
private let vadSilenceEndFrames = "audio.vad.silenceEndFrames"
private let sttStabilizationDelayFrames = "stt.stabilizationDelayFrames"

@Test
func raisingAllowByDefaultRiskIsRejected() async throws {
  let engine = try await makeConfigurationEngine()
  let result = try await engine.apply(
    ConfigurationPatch(
      layer: .projectSettings,
      values: [maximumAllowByDefaultRisk: .integer(3)],  // 3 = destructive
      source: "adversarial-test"))
  #expect(!result.accepted)
  #expect(result.warnings.contains { $0.contains(maximumAllowByDefaultRisk) })
}

@Test
func loweringMinimumConfirmationRiskIsRejected() async throws {
  let engine = try await makeConfigurationEngine()
  let result = try await engine.apply(
    ConfigurationPatch(
      layer: .projectSettings,
      values: [minimumConfirmationRisk: .integer(0)],  // 0 = observation
      source: "adversarial-test"))
  #expect(!result.accepted)
  #expect(result.warnings.contains { $0.contains(minimumConfirmationRisk) })
}

@Test
func higherTrustLayerBlocksLowerTrustLayerWeakening() async throws {
  let engine = try await makeConfigurationEngine()
  // Establish a machine-policy floor that locks the minimum confirmation risk.
  let machineResult = try await engine.apply(
    ConfigurationPatch(
      layer: .machinePolicy,
      values: [minimumConfirmationRisk: .integer(2)],
      source: "machine-policy-test"))
  #expect(machineResult.accepted)

  let attack = try await engine.apply(
    ConfigurationPatch(
      layer: .userSettings,
      values: [minimumConfirmationRisk: .integer(1)],
      source: "adversarial-test"))
  #expect(!attack.accepted)
}

@Test
func immutablePrivacyFlagCannotBeEnabled() async throws {
  let engine = try await makeConfigurationEngine()
  let result = try await engine.apply(
    ConfigurationPatch(
      layer: .projectSettings,
      values: [privacyRawTelemetryEnabled: .boolean(true)],
      source: "adversarial-test"))
  #expect(!result.accepted)
  #expect(result.warnings.contains { $0.contains(privacyRawTelemetryEnabled) })
}

@Test
func numberBelowMinimumIsRejected() async throws {
  let engine = try await makeConfigurationEngine()
  let result = try await engine.apply(
    ConfigurationPatch(
      layer: .userSettings,
      values: [vadSilenceEndFrames: .integer(1)],  // below schema minimum 3
      source: "adversarial-test"))
  #expect(!result.accepted)
  #expect(result.warnings.contains { $0.contains(vadSilenceEndFrames) })
}

@Test
func projectLayerMayNotIncreaseConcurrencyCap() async throws {
  let engine = try await makeConfigurationEngine()
  // Secure default is 1 and machine-policy may lock it.
  let result = try await engine.apply(
    ConfigurationPatch(
      layer: .projectSettings,
      values: [modelsMaxConcurrentLocalModels: .integer(3)],
      source: "adversarial-test"))
  #expect(!result.accepted)
  #expect(result.warnings.contains { $0.contains(modelsMaxConcurrentLocalModels) })
}

@Test
func acceptedPatchDoesNotBypassSecurityConstraint() async throws {
  let engine = try await makeConfigurationEngine()
  // Increasing stabilization delay is allowed (may not decrease), but we
  // confirm that the change is actually accepted and stored.
  let result = try await engine.apply(
    ConfigurationPatch(
      layer: .userSettings,
      values: [sttStabilizationDelayFrames: .integer(5)],
      source: "adversarial-test"))
  #expect(result.accepted)
  let effective = await engine.effectiveValue(for: sttStabilizationDelayFrames)
  #expect(effective == .integer(5))
}
