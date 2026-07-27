import Foundation

/// A redaction rule expressed as a regular expression.
public struct RedactionRule: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let pattern: String
  public let replacement: String

  public init(
    id: UUID = UUID(),
    pattern: String,
    replacement: String = "<redacted>"
  ) {
    self.id = id
    self.pattern = pattern
    self.replacement = replacement
  }
}

/// Applies a configured set of redaction rules to plain text.
///
/// The redactor is a value type and is safe to use from any isolation domain.
/// It is applied to command output **before** the output is emitted as an event
/// or forwarded to `AuraLogger`.
public struct OutputRedactor: Codable, Sendable, Equatable {
  public let rules: [RedactionRule]

  public init(rules: [RedactionRule] = []) {
    self.rules = rules
  }

  public init(patterns: [String]) {
    self.rules = patterns.map { RedactionRule(pattern: $0) }
  }

  /// Apply all redaction rules to the input string.
  public func redact(_ input: String) -> String {
    var output = input
    for rule in rules {
      output = output.replacingOccurrences(
        of: rule.pattern,
        with: rule.replacement,
        options: .regularExpression
      )
    }
    return output
  }

  /// Convenience redactor that replaces common secret shapes, sourced from
  /// the single canonical `SecretPatternLibrary` shared with
  /// `RepositoryInstructionsScanner` and `SecretScanner` (`AuraSecurity`).
  public static let `default` = OutputRedactor(patterns: SecretPatternLibrary.patterns)

  /// Redactor that replaces nothing. Useful in tests that need raw output.
  public static let passthrough = OutputRedactor(rules: [])
}
