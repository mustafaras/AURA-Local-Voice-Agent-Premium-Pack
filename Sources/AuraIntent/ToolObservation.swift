import AuraCore
import Foundation

/// A bounded, verified observation produced by a tool that actually ran.
///
/// SP-019 found that no production path ever turned a real tool result into
/// memory: the only live write was `IntentEngine.persistIntentAsMemory`, a
/// classifier summary with `.systemDerived` provenance and a per-intent
/// unique subject. That made two of the Memory Engine's stated properties
/// unreachable in the shipped product — a `projectFact` could never be
/// derived from tool evidence, and `ContradictionDetector` (which keys on
/// `(memoryClass, subject, scope)`) could never fire, because no two live
/// records ever shared a subject.
///
/// This type is the missing seam. A tool records what it *observed*, keyed by
/// a stable `factKey`, and the dispatch coordinator hands it to the memory
/// engine as `.verifiedToolEvidence`. Two observations of the same `factKey`
/// with different statements are exactly the contradiction the engine is
/// designed to surface.
///
/// The statement is deliberately bounded and separate from the spoken
/// summary: a tool's raw output must never become speech or unbounded
/// durable memory. The memory engine's secret screen is the final gate, so
/// a secret-looking output fails the write closed rather than being stored.
public struct ToolObservation: Sendable, Equatable {
  /// The capability that produced the observation (e.g. `shell.execute`).
  public let toolID: String
  /// Stable identity of the *fact*, not of this particular run. Repeated
  /// observations of the same fact must collide on this key so a changed
  /// answer is raised as a contradiction instead of silently accumulating.
  public let factKey: String
  /// Bounded, human-readable statement of what was observed.
  public let statement: String
  /// References to the concrete evidence behind the observation. Never empty:
  /// `MemoryEngine.validateVerifiedToolSource` rejects a tool-sourced write
  /// with no evidence.
  public let evidenceReferences: [String]
  /// The subsystem that made the observation, carried into
  /// `MemoryProvenance.observed(source:)`.
  public let sourceActor: ActorID
  public let observedAt: Date

  public init(
    toolID: String,
    factKey: String,
    statement: String,
    evidenceReferences: [String],
    sourceActor: ActorID,
    observedAt: Date = Date()
  ) {
    self.toolID = toolID
    self.factKey = factKey
    self.statement = statement
    self.evidenceReferences = evidenceReferences
    self.sourceActor = sourceActor
    self.observedAt = observedAt
  }

  /// Collapse arbitrary tool output into one bounded, single-line fragment.
  ///
  /// Multi-line output is reduced to its first non-empty line: a project fact
  /// is a short answer ("main"), and keeping only the first line stops a
  /// verbose command from writing an unbounded record. Control characters are
  /// dropped so nothing in a statement can forge the display of another field.
  public static func boundedOutput(_ raw: String, limit: Int = 200) -> String {
    let firstLine =
      raw
      .split(whereSeparator: \.isNewline)
      .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
      .map(String.init) ?? ""
    let printable = String(
      String.UnicodeScalarView(
        firstLine.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F }))
    return String(printable.trimmingCharacters(in: .whitespaces).prefix(limit))
  }
}
