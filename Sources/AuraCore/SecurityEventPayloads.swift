import Foundation

/// Emitted whenever a secret is stored, retrieved, or deleted through
/// `SecretStoring` (`AuraSecurity`). Never carries the secret value itself —
/// only the key and outcome, matching the universal event envelope rule
/// that raw credentials never appear in an event payload.
public struct SecretAccessEvent: EventPayload {
  public static let eventType = "security.secret.access"

  public enum Operation: String, Codable, Sendable, Equatable {
    case store
    case retrieve
    case delete
  }

  public let key: String
  public let operation: Operation
  public let succeeded: Bool

  public init(key: String, operation: Operation, succeeded: Bool) {
    self.key = key
    self.operation = operation
    self.succeeded = succeeded
  }
}

/// Emitted whenever `PromptInjectionClassifier` (`AuraSecurity`) reaches a
/// `.suspicious` or `.blocked` verdict on untrusted content. `.clean`
/// verdicts are not emitted — they are the overwhelming majority case and
/// carry no audit value, matching the project's "security ... events are
/// never sampled" rule for the signal that does matter (a real detection).
public struct InjectionVerdictEvent: EventPayload {
  public static let eventType = "security.injection.verdict"

  public let provenance: String
  public let verdict: String
  public let categories: [String]
  public let highestSeverity: Int

  public init(provenance: String, verdict: String, categories: [String], highestSeverity: Int) {
    self.provenance = provenance
    self.verdict = verdict
    self.categories = categories
    self.highestSeverity = highestSeverity
  }
}

/// Emitted whenever `NetworkAllowlist` (`AuraSecurity`) evaluates an
/// outbound-network target.
public struct NetworkAllowlistDecisionEvent: EventPayload {
  public static let eventType = "security.network.decision"

  public let host: String
  public let allowed: Bool
  public let reason: String

  public init(host: String, allowed: Bool, reason: String) {
    self.host = host
    self.allowed = allowed
    self.reason = reason
  }
}
