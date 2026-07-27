import AuraCore
import Foundation

/// One detected secret-shaped span.
public struct SecretMatch: Sendable, Equatable {
  public let patternName: String
  /// The matched span's start offset in UTF-16 code units — sufficient for
  /// callers that need to redact or report a location without re-exposing
  /// the matched text itself.
  public let range: Range<Int>
}

/// Pre-flight secret scanning for content about to be persisted (ledger
/// entries, memory records) or sent to a model (prompts, context bundles) —
/// distinct from `OutputRedactor`, which *replaces* matches in command
/// output already destined for a log. `SecretScanner` instead reports typed
/// matches so a caller can decide to block outright rather than merely mask.
///
/// Built on the same canonical `SecretPatternLibrary` as `OutputRedactor
/// .default` and `RepositoryInstructionsScanner`, so all three call sites
/// recognize exactly the same secret shapes.
public struct SecretScanner: Sendable {
  private let compiledPatterns: [(name: String, regex: NSRegularExpression)]

  public init() {
    self.compiledPatterns = SecretPatternLibrary.all.compactMap { definition in
      guard let regex = try? NSRegularExpression(pattern: definition.pattern) else { return nil }
      return (definition.name, regex)
    }
  }

  /// Return every detected secret-shaped match in `text`. Empty when clean.
  public func scan(_ text: String) -> [SecretMatch] {
    guard !text.isEmpty else { return [] }
    let utf16 = text.utf16
    let fullRange = NSRange(location: 0, length: utf16.count)
    var matches: [SecretMatch] = []
    for (name, regex) in compiledPatterns {
      regex.enumerateMatches(in: text, options: [], range: fullRange) { result, _, _ in
        guard let result else { return }
        matches.append(SecretMatch(patternName: name, range: result.range.location..<result.range.location + result.range.length))
      }
    }
    return matches
  }

  /// Convenience boolean check for callers that only need a yes/no gate.
  public func containsSecret(_ text: String) -> Bool {
    !scan(text).isEmpty
  }
}
