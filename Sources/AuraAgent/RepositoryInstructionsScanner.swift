import AuraCore
import Foundation

/// Scans repository customization files for secret-looking content before a
/// Copilot run, implementing the restriction stated in
/// `docs/subsystems/19_COPILOT_CONTROLLER.md`: "Do not place secrets or
/// private user context in repository instructions."
///
/// Covers the files named in the same subsystem doc
/// (`.github/copilot-instructions.md`, `.github/instructions/*.instructions.md`,
/// `.github/agents/*.agent.md`, `.github/prompts/*.prompt.md`) plus
/// `AGENTS.md`, which `copilot -p` also auto-loads unless
/// `--no-custom-instructions` is passed (verified via `copilot --help`).
public enum RepositoryInstructionsScanner {
  public struct ScanResult: Sendable, Equatable {
    public let filesScanned: [String]
    public let secretsDetected: Bool
    public let blockedFiles: [String]

    public init(filesScanned: [String], secretsDetected: Bool, blockedFiles: [String]) {
      self.filesScanned = filesScanned
      self.secretsDetected = secretsDetected
      self.blockedFiles = blockedFiles
    }
  }

  /// Sourced from the same canonical `SecretPatternLibrary` used by
  /// `OutputRedactor.default` and `SecretScanner` (`AuraSecurity`) — see
  /// that type for why the list covers named secret shapes only, not a
  /// generic key=value heuristic.
  private static let secretDetector = OutputRedactor(patterns: SecretPatternLibrary.patterns)

  private static let candidateRelativeFiles: [String] = [
    ".github/copilot-instructions.md",
    "AGENTS.md",
  ]

  private static let candidateDirectories: [(directory: String, suffix: String)] = [
    (".github/instructions", ".instructions.md"),
    (".github/agents", ".agent.md"),
    (".github/prompts", ".prompt.md"),
  ]

  /// Scan every repository-customization file that exists under
  /// `repositoryRoot`. Missing files/directories are simply skipped, not
  /// treated as an error.
  public static func scan(repositoryRoot: String) -> ScanResult {
    let fileManager = FileManager.default
    var filesScanned: [String] = []
    var blockedFiles: [String] = []

    for relativePath in candidateRelativeFiles {
      let fullPath = (repositoryRoot as NSString).appendingPathComponent(relativePath)
      guard fileManager.fileExists(atPath: fullPath) else { continue }
      filesScanned.append(fullPath)
      if containsSecret(atPath: fullPath) {
        blockedFiles.append(fullPath)
      }
    }

    for (directory, suffix) in candidateDirectories {
      let fullDirectory = (repositoryRoot as NSString).appendingPathComponent(directory)
      guard let entries = try? fileManager.contentsOfDirectory(atPath: fullDirectory) else {
        continue
      }
      for entry in entries.sorted() where entry.hasSuffix(suffix) {
        let fullPath = (fullDirectory as NSString).appendingPathComponent(entry)
        filesScanned.append(fullPath)
        if containsSecret(atPath: fullPath) {
          blockedFiles.append(fullPath)
        }
      }
    }

    return ScanResult(
      filesScanned: filesScanned, secretsDetected: !blockedFiles.isEmpty,
      blockedFiles: blockedFiles)
  }

  private static func containsSecret(atPath path: String) -> Bool {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
      return false
    }
    return secretDetector.redact(content) != content
  }
}
