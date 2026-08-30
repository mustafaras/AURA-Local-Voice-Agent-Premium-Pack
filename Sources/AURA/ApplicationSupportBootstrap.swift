import Foundation

enum ApplicationSupportBootstrap {
  static func databaseURL(
    fileManager: FileManager = .default,
    baseDirectory: URL? = nil
  ) throws -> URL {
    let applicationSupport =
      baseDirectory
      ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let auraDirectory = applicationSupport.appendingPathComponent("AURA", isDirectory: true)
    try fileManager.createDirectory(
      at: auraDirectory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    return auraDirectory.appendingPathComponent("aura.db", isDirectory: false)
  }

  static func urlFor(
    directory: FileManager.SearchPathDirectory,
    subpath: String,
    fileManager: FileManager = .default
  ) -> URL {
    let base = fileManager.urls(for: directory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let result = base.appendingPathComponent(subpath, isDirectory: true)
    try? fileManager.createDirectory(
      at: result, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    return result
  }
}
