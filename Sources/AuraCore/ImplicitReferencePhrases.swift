import Foundation

/// The phrases that mean "the thing we were just talking about".
///
/// This list decides whether an utterance carries an implicit reference, and
/// three layers must agree on it: `ContextBuilder` parses one out of the
/// utterance, `IntentEngine` gates guarded actions on it, and the rule-based
/// classifier uses it to tell "open the file" (a reference) from "open safari"
/// (an application name). It lived as three separate literals; a phrase added
/// to one copy silently did nothing in the others, so it is defined once here.
public enum ImplicitReferencePhrases: Sendable {
  /// Ordered longest-intent-first: "that repository" must win over "that", and
  /// "the last one" over "the file", so the matched phrase names the most
  /// specific entity the user could have meant.
  public static let all: [String] = [
    "previous test", "last test", "that repo", "that repository", "the repository",
    "the repo", "the draft", "send the draft", "ask claude", "ask codex", "ask copilot",
    "last file", "previous file", "the last one", "the file", "the document", "the app",
    "that", "it",
  ]

  /// Phrases that name an application rather than a document. An implicit
  /// reference to "the app" must resolve against recent applications, not
  /// recent files, or `TypedIntent.applyingResolvedReference` can never bind it.
  public static let applicationPhrases: Set<String> = ["the app"]

  /// The first phrase present in `text`, or `nil`.
  ///
  /// Multi-word phrases match as substrings; a single word must match a whole
  /// word, so "it" does not fire inside "edit" or "safari".
  public static func firstMatch(in text: String) -> String? {
    let normalized = text.lowercased()
    return all.first { contains(normalized, phrase: $0) }
  }

  public static func contains(_ text: String, phrase: String) -> Bool {
    if phrase.contains(" ") { return text.contains(phrase) }
    let words = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    return words.contains(phrase)
  }
}
