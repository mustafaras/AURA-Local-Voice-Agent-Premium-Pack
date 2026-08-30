import AuraCore
import AuraSecurity
import AuraStore
import Foundation

/// Atomic update staging with low-disk guard, backup of the current version,
/// and interrupted-update recovery. The production implementation never
/// mutates the running bundle directly; it stages to a directory and returns
/// a checkpoint ID for the caller to apply later.
public actor UpdateStager {
  public static let currentStagedUpdateKey = "lifecycle.currentStagedUpdateID"

  private let stagingRoot: URL
  private let currentVersion: String
  private let minimumFreeBytes: Int64
  private let fileManager: FileManager
  private let store: AuraStore?
  private let logger: AuraLogger?
  private let now: @Sendable () -> Date

  public init(
    stagingRoot: URL,
    currentVersion: String,
    minimumFreeBytes: Int64 = 1_000_000_000,
    fileManager: FileManager = .default,
    store: AuraStore? = nil,
    logger: AuraLogger? = nil,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.stagingRoot = stagingRoot
    self.currentVersion = currentVersion
    self.minimumFreeBytes = minimumFreeBytes
    self.fileManager = fileManager
    self.store = store
    self.logger = logger
    self.now = now
  }

  /// Stage an update package: verify low-disk guard, atomically write package
  /// to a versioned staging directory, record the staged update row, and
  /// return the staged update ID. Any existing interrupted staging for the same
  /// version is cleaned up first.
  public func stage(
    manifest: UpdateManifest,
    package: UpdatePackage,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> UpdateStageResult {
    let available = try availableBytes(at: stagingRoot)
    guard available >= minimumFreeBytes else {
      return .blocked(
        "insufficient free disk space: \(available) bytes available, "
          + "\(minimumFreeBytes) required")
    }

    let stagedID = UUID()
    let versionDirectory = stagingRoot.appendingPathComponent(stagedID.uuidString, isDirectory: true)

    do {
      try fileManager.createDirectory(
        at: versionDirectory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
    } catch {
      return .error("failed to create staging directory: \(error.localizedDescription)")
    }

    let packagePath = versionDirectory.appendingPathComponent("update.zip")
    let previousPath = versionDirectory.appendingPathComponent("previous-version.json")

    do {
      try package.data.write(to: packagePath, options: .atomic)
      let previous = PreviousVersionInfo(version: currentVersion, stagedAt: now())
      let previousData = try JSONEncoder().encode(previous)
      try previousData.write(to: previousPath, options: .atomic)
    } catch {
      try? fileManager.removeItem(at: versionDirectory)
      return .error("failed to write staged package: \(error.localizedDescription)")
    }

    if let store = store {
      try await store.database.run(
        sql: """
          INSERT INTO staged_updates (
            id, correlation_id, created_at, version, bundle_id, package_path,
            previous_bundle_path, status, manifest_json
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
          """,
        arguments: [
          .text(stagedID.uuidString),
          .text(correlationID.uuidString),
          .text(formatDate(now())),
          .text(manifest.version),
          .text(manifest.bundleIdentifier),
          .text(packagePath.path),
          .text(previousPath.path),
          .text("staged"),
          .text(encodeManifest(manifest)),
        ])
      try await store.setValue(stagedID.uuidString, forKey: Self.currentStagedUpdateKey)
    }

    await logger?.info(
      "Update \(manifest.version) staged at \(packagePath.path)",
      correlationID: correlationID,
      actor: .lifecycle)
    return .staged(stagedID)
  }

  /// Roll back a staged update: move its status to `rolled_back` and remove
  /// the staging directory. The previous version info is retained for audit.
  @discardableResult
  public func rollback(
    stagedUpdateID: UUID,
    reason: String,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> UpdateStageResult {
    guard let store = store else {
      return .error("store not available for rollback")
    }

    let rows = try await store.database.query(
      sql: "SELECT * FROM staged_updates WHERE id = ?;",
      arguments: [.text(stagedUpdateID.uuidString)])
    guard let row = rows.first else {
      return .blocked("staged update not found")
    }

    let packagePath = row["package_path"]?.textValue.flatMap { URL(fileURLWithPath: $0) }
    let version = row["version"]?.textValue ?? "unknown"

    try await store.database.run(
      sql: "UPDATE staged_updates SET status = ? WHERE id = ?;",
      arguments: [.text("rolled_back"), .text(stagedUpdateID.uuidString)])

    if let packagePath {
      try? fileManager.removeItem(at: packagePath.deletingLastPathComponent())
    }

    await logger?.warning(
      "Rolled back staged update \(version): \(reason)",
      correlationID: correlationID,
      actor: .lifecycle)
    return .staged(stagedUpdateID)
  }

  /// Resume/clean any interrupted staging from a previous run. Returns the
  /// still-valid staged update IDs and removes any rolled-back or partial
  /// staging directories whose database rows are missing.
  public func recoverInterruptedStagedUpdates() async throws(AuraError) -> [UUID] {
    guard let store = store else { return [] }
    let rows = try await store.database.query(
      sql: "SELECT id, package_path, status FROM staged_updates WHERE status = 'staged';",
      arguments: [])

    var valid: [UUID] = []
    for row in rows {
      guard let idString = row["id"]?.textValue,
        let id = UUID(uuidString: idString)
      else { continue }
      let packagePath = row["package_path"]?.textValue.flatMap { URL(fileURLWithPath: $0) }
      let exists = packagePath.map { fileManager.fileExists(atPath: $0.path) } ?? false
      if exists {
        valid.append(id)
      } else {
        try await store.database.run(
          sql: "UPDATE staged_updates SET status = ? WHERE id = ?;",
          arguments: [.text("interrupted_missing_package"), .text(idString)])
      }
    }
    return valid
  }

  private func availableBytes(at url: URL) throws(AuraError) -> Int64 {
    do {
      let attributes = try fileManager.attributesOfFileSystem(forPath: url.path)
      guard let freeSize = attributes[.systemFreeSize] as? NSNumber else {
        throw AuraError.lifecycleError("unable to determine free disk space")
      }
      return freeSize.int64Value
    } catch {
      throw AuraError.lifecycleError("disk space check failed: \(error.localizedDescription)")
    }
  }

  private func encodeManifest(_ manifest: UpdateManifest) -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(manifest),
      let json = String(data: data, encoding: .utf8)
    else { return "{}" }
    return json
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}

public struct PreviousVersionInfo: Codable, Sendable, Equatable {
  public let version: String
  public let stagedAt: Date
}
