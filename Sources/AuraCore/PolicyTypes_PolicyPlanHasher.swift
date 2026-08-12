import CryptoKit
import Foundation

/// Stable hash of the exact policy-relevant plan fields. Volatile request IDs,
/// causation IDs, nonces, and expiry timestamps are intentionally excluded so
/// the same plan can be revalidated before one-time execution.
public enum PolicyPlanHasher {
  private struct Fingerprint: Codable {
    let capability: Capability
    let actor: ActorID
    let target: PolicyTarget
    let arguments: [String]
    let environment: [String: String]
  }

  public static func hash(
    capability: Capability,
    actor: ActorID,
    target: PolicyTarget,
    arguments: [String] = [],
    environment: [String: String] = [:]
  ) -> String {
    let fingerprint = Fingerprint(
      capability: capability,
      actor: actor,
      target: target,
      arguments: arguments,
      environment: environment)
    let data = encode(fingerprint)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  /// `Fingerprint` is intentionally composed only of repository-owned Codable
  /// value types. Encoding failure therefore indicates a source invariant
  /// regression; fail explicitly instead of hiding it behind a forced throw.
  private static func encode(_ fingerprint: Fingerprint) -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    do {
      return try encoder.encode(fingerprint)
    } catch {
      preconditionFailure(
        "PolicyPlanHasher fingerprint encoding invariant failed: \(String(describing: error))")
    }
  }

  public static func hash(_ request: PolicyEvaluationRequest) -> String {
    hash(
      capability: request.capability,
      actor: request.actor,
      target: request.target,
      arguments: request.arguments,
      environment: request.environment)
  }
}
