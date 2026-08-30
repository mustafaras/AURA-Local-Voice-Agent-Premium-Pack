import AuraConfig
import AuraCore
import AuraStore
import Foundation

/// Orchestrates the local update flow: check availability, validate,
/// user approval, atomic staging, and kill-switch gating. Network access is
/// delegated to a `UpdateManifestSource`; the default production source
/// returns `.noUpdateAvailable`.
public actor UpdateEngine {
  private let validator: UpdatePackageValidator
  private let stager: UpdateStager?
  private let configurationEngine: ConfigurationEngine?
  private let manifestSource: any UpdateManifestSource
  private let eventBus: AuraEventBus?
  private let healthRegistry: RuntimeHealthRegistry?
  private let logger: AuraLogger?

  public init(
    validator: UpdatePackageValidator,
    stager: UpdateStager? = nil,
    configurationEngine: ConfigurationEngine? = nil,
    manifestSource: (any UpdateManifestSource)? = nil,
    eventBus: AuraEventBus? = nil,
    healthRegistry: RuntimeHealthRegistry? = nil,
    logger: AuraLogger? = nil
  ) {
    self.validator = validator
    self.stager = stager
    self.configurationEngine = configurationEngine
    self.manifestSource = manifestSource ?? NoUpdateManifestSource()
    self.eventBus = eventBus
    self.healthRegistry = healthRegistry
    self.logger = logger
  }

  /// Whether automatic update checks are enabled by configuration.
  public func automaticChecksEnabled() async -> Bool {
    guard let engine = configurationEngine else { return false }
    guard case .boolean(let value) = await engine.effectiveValue(
      for: "lifecycle.automaticUpdateChecksEnabled")
    else { return false }
    return value
  }

  /// Public check path. Returns `.noUpdateAvailable` if disabled or no source.
  public func checkForUpdate(actor: ActorID = .user) async -> UpdateCheckResult {
    guard await automaticChecksEnabled() else {
      await recordHealth(.disabledByConfiguration, "automatic update checks disabled")
      return .noUpdateAvailable
    }

    let channel = await currentChannel()
    await emit(UpdateCheckRequestedEvent(channel: channel, actor: actor), .internalLevel)

    let result = await manifestSource.latestManifest(forChannel: channel)
    switch result {
    case .noUpdateAvailable:
      await recordHealth(.ready, "no update available")
      return .noUpdateAvailable
    case .error(let detail):
      await recordHealth(.degraded, "update check error: \(detail)")
      return .error(detail)
    case .manifest(let manifest):
      let validation = validator.validate(manifest: manifest)
      switch validation {
      case .valid:
        await recordHealth(.ready, "update available \(manifest.version)")
        return .updateAvailable(manifest)
      case .invalid(let failure):
        await recordHealth(.degraded, "manifest validation failed: \(String(describing: failure))")
        return .error("manifest invalid: \(String(describing: failure))")
      }
    }
  }

  /// Download, validate, and stage an update. Requires an explicit
  /// user-controlled approval flag because this is a destructive-tier action.
  public func stageUpdate(
    manifest: UpdateManifest,
    approved: Bool,
    actor: ActorID = .user
  ) async -> UpdateStageResult {
    guard approved else {
      return .blocked("update staging requires explicit user approval")
    }
    guard let stager = stager else {
      return .error("stager not configured")
    }

    let packageResult = await manifestSource.downloadPackage(manifest: manifest)
    switch packageResult {
    case .noUpdateAvailable:
      return .error("package unavailable")
    case .error(let detail):
      return .error("package download failed: \(detail)")
    case .package(let package):
      let validation = validator.validate(manifest: manifest, package: package)
      guard case .valid = validation else {
        return .error("package validation failed: \(String(describing: validation))")
      }

      let correlationID = UUID()
      do {
        let result = try await stager.stage(
          manifest: manifest,
          package: package,
          correlationID: correlationID)
        if case .staged(let id) = result {
          await emit(UpdateStagedEvent(stagedUpdateID: id, version: manifest.version, actor: actor), .internalLevel)
          await recordHealth(.ready, "update \(manifest.version) staged")
        } else {
          await recordHealth(.failed, "staging blocked: \(String(describing: result))")
        }
        return result
      } catch {
        await recordHealth(.failed, "staging error: \(error.localizedDescription)")
        return .error("staging error: \(error.localizedDescription)")
      }
    }
  }

  /// Roll back the currently staged update.
  public func rollbackStagedUpdate(
    stagedUpdateID: UUID,
    reason: String,
    actor: ActorID = .user
  ) async -> UpdateStageResult {
    guard let stager = stager else {
      return .error("stager not configured")
    }
    do {
      let result = try await stager.rollback(
        stagedUpdateID: stagedUpdateID,
        reason: reason,
        correlationID: UUID())
      await emit(
        UpdateRolledBackEvent(stagedUpdateID: stagedUpdateID, version: "", reason: reason, actor: actor),
        .internalLevel)
      await recordHealth(.ready, "rolled back staged update")
      return result
    } catch {
      await recordHealth(.failed, "rollback error: \(error.localizedDescription)")
      return .error("rollback error: \(error.localizedDescription)")
    }
  }

  private func currentChannel() async -> String {
    guard let engine = configurationEngine else { return "none" }
    guard case .string(let value) = await engine.effectiveValue(for: "lifecycle.updateChannel") else {
      return "none"
    }
    return value
  }

  private func recordHealth(_ status: RuntimeHealthStatus, _ detail: String) async {
    await healthRegistry?.record(componentID: "update-engine", status: status, detail: detail)
  }

  private func emit<P: EventPayload>(_ payload: P, _ sensitivity: SensitivityLevel) async {
    guard let eventBus = eventBus else { return }
    await eventBus.emit(
      EventEnvelope(
        correlationID: UUID(),
        causationID: UUID(),
        actor: .lifecycle,
        sensitivity: sensitivity,
        payload: payload))
  }
}

// MARK: - Manifest source abstraction

public enum UpdateManifestSourceResult: Sendable, Equatable {
  case noUpdateAvailable
  case manifest(UpdateManifest)
  case error(String)
}

public enum UpdatePackageSourceResult: Sendable, Equatable {
  case noUpdateAvailable
  case package(UpdatePackage)
  case error(String)
}

public protocol UpdateManifestSource: Sendable {
  func latestManifest(forChannel channel: String) async -> UpdateManifestSourceResult
  func downloadPackage(manifest: UpdateManifest) async -> UpdatePackageSourceResult
}

/// Default production source: update checks are disabled until the project
/// is configured with a real endpoint and signing pipeline.
public struct NoUpdateManifestSource: UpdateManifestSource {
  public init() {}

  public func latestManifest(forChannel channel: String) async -> UpdateManifestSourceResult {
    .noUpdateAvailable
  }

  public func downloadPackage(manifest: UpdateManifest) async -> UpdatePackageSourceResult {
    .noUpdateAvailable
  }
}
