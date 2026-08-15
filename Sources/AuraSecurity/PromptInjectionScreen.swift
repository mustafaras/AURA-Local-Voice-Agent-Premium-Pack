import AuraCore
import Foundation

/// Single enforcement point for "untrusted text must not reach a model as an
/// instruction."
///
/// `PromptInjectionClassifier` decides *whether* a span looks like an
/// injection; this decides *what a prompt builder does about it*. Keeping that
/// second half in one place matters: the classifier already existed and was
/// already correct when a live local model was successfully hijacked by an
/// approved context item, because the detector was simply never called on that
/// path (`EV-SP-003-20260815-LIVE-7SCENARIO-16`). Every prompt builder that
/// interpolates non-authoritative content should route it through here rather
/// than re-deriving the policy.
///
/// Withheld content is replaced by a visible marker instead of being dropped
/// silently, so the model — and anyone reading a trace afterwards — can tell
/// that a source was consulted and refused, rather than that it never existed.
/// A reviewer whose diff is withheld therefore cannot approve on faith; it
/// fails closed.
public struct PromptInjectionScreen: Sendable {
  public static let withheldMarker = "[withheld: content failed injection screening]"

  private let classifier: PromptInjectionClassifier

  public init(classifier: PromptInjectionClassifier = PromptInjectionClassifier()) {
    self.classifier = classifier
  }

  /// Returns `text` unchanged when it is clean, or the withheld marker when the
  /// classifier blocks it.
  ///
  /// `provenance` must describe where the text genuinely came from. Content
  /// that `carriesAuthority` (the live user, AURA's own policy) is never
  /// scanned — it cannot inject into itself — so callers must not pass an
  /// authoritative provenance for content merely *claiming* to be
  /// authoritative.
  public func screen(_ text: String, provenance: ContentProvenance) -> String {
    classifier.classify(text, provenance: provenance).isBlocked
      ? Self.withheldMarker
      : text
  }

  /// Screen and report, for callers that need to react to the refusal (fail a
  /// review, escalate, or annotate an audit event) rather than only substitute.
  public func screenReporting(
    _ text: String,
    provenance: ContentProvenance
  ) -> (text: String, wasWithheld: Bool) {
    let blocked = classifier.classify(text, provenance: provenance).isBlocked
    return (blocked ? Self.withheldMarker : text, blocked)
  }
}
