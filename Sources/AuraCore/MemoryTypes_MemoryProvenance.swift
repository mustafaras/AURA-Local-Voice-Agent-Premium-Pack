import Foundation

// MARK: - Provenance

/// How a memory record's statement came to be known.
///
/// `.inferred` exists specifically so inference is always labeled, never
/// presented as directly observed or user-stated fact — one of the Memory
/// Engine's normative rules ("Inference is labeled").
public enum MemoryProvenance: Codable, Sendable, Equatable {
  /// The user directly stated this.
  case userStated
  /// Directly observed by a named subsystem (e.g. a tool result, a file
  /// read, a policy decision) rather than asserted by the user.
  case observed(source: ActorID)
  /// Derived by inference rather than directly observed or stated.
  /// `basis` names the reasoning or signal the inference rests on.
  case inferred(basis: String)
  /// Derived deterministically by a system process (e.g. a task-state
  /// projection), not inferred from ambiguous signals.
  case systemDerived(source: ActorID)
}
