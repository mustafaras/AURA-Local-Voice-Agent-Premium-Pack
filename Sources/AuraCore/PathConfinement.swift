import Foundation

/// Canonicalization-based path confinement.
///
/// `Command.validate` (`AuraShell`) and `WorkingDirectoryAllowlist`
/// (`AuraAgent`) already enforce path allowlists, but both do so with a
/// naive string prefix/substring check against the *un-canonicalized* path
/// (expanding `$VAR`/`~` only) — see ADR-020 decision on residual risk.
/// `PathConfinement` is the hardened primitive new Phase 19 code (`Aura
/// Security`, `AuraPlugins`) uses instead: it resolves `..` segments and
/// symlinks before comparing, so `/allowed/../etc/passwd` or a symlink that
/// escapes an allowed root cannot be mistaken for a contained path.
public enum PathConfinement {
  /// Expand `~` and `$VAR` references, then resolve the path to an absolute,
  /// symlink-free, `.`/`..`-free canonical form. The path need not exist —
  /// non-existent trailing components are preserved verbatim (only the
  /// deepest existing prefix is resolved through symlinks), matching the
  /// common case of validating a path before it is created.
  public static func canonicalize(_ path: String) -> String {
    let expanded = expandVariables(path)
    let url = URL(fileURLWithPath: expanded)
    let standardized = url.standardizedFileURL
    let resolved = standardized.resolvingSymlinksInPath()
    return resolved.path
  }

  /// True when `path`, once canonicalized, is exactly one of `roots` or a
  /// descendant of one of them (each root is itself canonicalized first).
  /// Component-wise, not a raw string prefix: `/allowed-evil` is never
  /// treated as contained under root `/allowed`.
  public static func isContained(_ path: String, within roots: some Sequence<String>) -> Bool {
    let candidate = canonicalize(path)
    let candidateComponents = URL(fileURLWithPath: candidate).pathComponents
    for root in roots {
      let rootComponents = URL(fileURLWithPath: canonicalize(root)).pathComponents
      guard candidateComponents.count >= rootComponents.count else { continue }
      if Array(candidateComponents.prefix(rootComponents.count)) == rootComponents {
        return true
      }
    }
    return false
  }

  private static func expandVariables(_ path: String) -> String {
    var result = path
    let environment = ProcessInfo.processInfo.environment
    for (key, value) in environment where result.contains("$\(key)") {
      result = result.replacingOccurrences(of: "$\(key)", with: value)
    }
    if result.hasPrefix("~") {
      result = (environment["HOME"] ?? "/") + String(result.dropFirst())
    }
    return result
  }
}
