import AuraCore
import CryptoKit
import Foundation

/// Captures before/after filesystem hashes for directories named in a command.
///
/// Evidence is deterministic, scoped to the command execution ID, and never
/// includes file contents—only stable SHA-256 hashes of relative paths and
/// filesystem metadata.
public actor FilesystemEvidence {
  public struct Snapshot: Codable, Sendable, Equatable {
    public let executionID: UUID
    public let path: String
    public let capturedAt: TimeInterval
    public let entries: [Entry]

    public init(
      executionID: UUID,
      path: String,
      capturedAt: TimeInterval,
      entries: [Entry]
    ) {
      self.executionID = executionID
      self.path = path
      self.capturedAt = capturedAt
      self.entries = entries
    }
  }

  public struct Entry: Codable, Sendable, Equatable {
    public let relativePath: String
    public let sha256: String
    public let modificationTime: TimeInterval
    public let size: Int

    public init(
      relativePath: String,
      sha256: String,
      modificationTime: TimeInterval,
      size: Int
    ) {
      self.relativePath = relativePath
      self.sha256 = sha256
      self.modificationTime = modificationTime
      self.size = size
    }
  }

  public init() {}

  /// Capture a snapshot of the directory at `path`, restricted to files.
  public func capture(
    executionID: UUID,
    path: String
  ) async -> Snapshot {
    let url = URL(fileURLWithPath: path)
    var entries: [Entry] = []
    let enumerator = FileManager.default.enumerator(
      at: url,
      includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    )
    while let item = enumerator?.nextObject() as? URL {
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory),
        !isDirectory.boolValue
      else { continue }
      guard let relative = URL(fileURLWithPath: path).relativePath(for: item) else { continue }
      let values = try? item.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
      let data = Data(relative.utf8)
      let sha256 = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
      entries.append(
        Entry(
          relativePath: relative,
          sha256: sha256,
          modificationTime: values?.contentModificationDate?.timeIntervalSince1970 ?? 0,
          size: values?.fileSize ?? 0
        )
      )
    }
    entries.sort { $0.relativePath < $1.relativePath }
    return Snapshot(
      executionID: executionID,
      path: path,
      capturedAt: Date().timeIntervalSince1970,
      entries: entries
    )
  }

  /// Return a hash describing the union of a before and after snapshot.
  public func diffDigest(before: Snapshot, after: Snapshot) -> String {
    var components: [String] = []
    let beforeByPath = Dictionary(
      uniqueKeysWithValues: before.entries.map { ($0.relativePath, $0) })
    let afterByPath = Dictionary(uniqueKeysWithValues: after.entries.map { ($0.relativePath, $0) })
    let allPaths = Set(beforeByPath.keys).union(afterByPath.keys).sorted()
    for path in allPaths {
      let beforeEntry = beforeByPath[path]
      let afterEntry = afterByPath[path]
      switch (beforeEntry, afterEntry) {
      case (.none, .some(let added)):
        components.append("+ \(added.relativePath) \(added.sha256)")
      case (.some(let removed), .none):
        components.append("- \(removed.relativePath) \(removed.sha256)")
      case (.some(let old), .some(let new)):
        if old.sha256 != new.sha256 || old.size != new.size {
          components.append("~ \(new.relativePath) \(old.sha256) \(new.sha256)")
        }
      case (.none, .none):
        break
      }
    }
    let data = Data(components.joined(separator: "\n").utf8)
    return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
  }
}

extension URL {
  fileprivate func relativePath(for descendant: URL) -> String? {
    let base = self.standardizedFileURL.path
    let child = descendant.standardizedFileURL.path
    guard child.hasPrefix(base) else { return nil }
    let remainder = child.dropFirst(base.count)
    if remainder.isEmpty { return "." }
    let trimmed = remainder.hasPrefix("/") ? remainder.dropFirst() : remainder
    return String(trimmed)
  }
}
