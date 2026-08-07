import Foundation

/// Result of verifying a step against its semantic postcondition.
public enum ComputerUseVerificationVerdict: Sendable, Equatable {
  case passed
  case failed(reason: String)
  case notApplicable
}

/// Evaluates a step's declared `expectedPostcondition` against the
/// post-action observation using an app-specific semantic predicate, with
/// the content-hash change available only as an additional signal — never
/// sufficient on its own. This is the R4 Verification section's
/// "Hash change alone is insufficient for success."
public struct ComputerUseVerifier: Sendable {
  public init() {}

  /// Verify one step given its intended semantic postcondition (as a
  /// predicate) and the pre-/post-action observations.
  ///
  /// - Parameter postcondition: the semantic predicate the step must satisfy;
  ///   `nil` means no semantic predicate is declared, which fails (the
  ///   prompt requires semantic postconditions, not a bare hash diff).
  /// - Parameter preAction: observation captured before the step.
  /// - Parameter postAction: observation captured after the step.
  public func verify(
    postcondition: ComputerUsePostcondition?,
    preAction: ComputerUseObservation,
    postAction: ComputerUseObservation
  ) -> ComputerUseVerificationVerdict {
    guard let postcondition else {
      return .failed(reason: "no semantic postcondition declared; hash alone is insufficient")
    }
    let contentChanged = preAction.contentHash != postAction.contentHash
    let semanticPassed = postcondition.isSatisfied(by: postAction)
    if semanticPassed {
      return .passed
    }
    // Semantic predicate failed. Note explicitly whether content changed,
    // to record that a hash change alone did NOT constitute success.
    if contentChanged {
      return .failed(reason: "content changed but semantic postcondition '\(postcondition.id)' not satisfied")
    }
    return .failed(reason: "semantic postcondition '\(postcondition.id)' not satisfied and no content change observed")
  }
}
