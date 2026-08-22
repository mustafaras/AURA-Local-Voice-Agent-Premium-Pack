import AuraCore
import AuraIntent
import AuraSTT
import Foundation
import Testing

/// SP-016 / OPEN-08: locks the fail-closed behaviour for the code-switched
/// technical transcripts that the bilingual quality probe actually produced.
///
/// The probe (`scripts/run-sp016-speech-probe.sh`, evidence
/// `EV-SP-016-20260822-BILINGUAL-QUALITY-03`) drove synthesized Turkish and
/// English speech through the real `SystemSTTEngine` on this Mac. Turkish and
/// English conversational and command utterances came back with entity recall
/// 1.000. English technical tokens embedded in Turkish sentences did not:
/// `npm install` was heard as "DPM insan" / "Mnsa", and `pull request` as
/// "Kırık ve" or dropped entirely. Adding the terms as contextual hints did
/// not recover them.
///
/// That is a measured capability limit, not a bug to paper over. The danger it
/// creates is the one SP-016 names explicitly: *never rewrite a bad transcript
/// into a successful command*. These tests use the verbatim garbled transcripts
/// as regression input and assert the pipeline degrades safely rather than
/// guessing what the user meant.
@Suite("SP-016 bilingual fail-closed behaviour")
struct SP016BilingualFailClosedTests {

  /// Transcripts observed verbatim in the probe run. Kept exactly as the
  /// recognizer emitted them — normalizing them here would test a string that
  /// the system never actually sees.
  private static let garbledTechnicalTranscripts: [(raw: String, normalized: String)] = [
    ("Terminal DPM insan çalıştır", "terminal dpm insan çalıştır"),
    ("Terminal de Mnsa çalıştır", "terminal de mnsa çalıştır"),
    ("Terminalden npm insan çalıştır", "terminalden npm insan çalıştır"),
    ("Terminalde Mnsa çalıştır", "terminalde mnsa çalıştır"),
    ("Kırık ve açıklamasını özetle", "kırık ve açıklamasını özetle"),
    ("Ve açıklamasını özetle", "ve açıklamasını özetle"),
    ("1 PM installing the terminal", "1 pm installing the terminal"),
    ("Run and p.m. install in the terminal", "run and p.m. install in the terminal"),
  ]

  /// A mis-heard technical phrase must never reach a destructive category.
  /// `shellDestructive` and `codingAgentRun` are the two tiers that can delete
  /// work or drive an agent, so a transcript the recognizer got wrong must not
  /// land there under any circumstances.
  @Test("Garbled technical transcripts never classify as destructive")
  func garbledTranscriptsNeverReachDestructiveTier() {
    let classifier = RuleBasedUtteranceClassifier()

    for sample in Self.garbledTechnicalTranscripts {
      let result = classifier.classify(normalized: sample.normalized, raw: sample.raw)
      #expect(
        result.semanticCategory.riskTier != .destructive,
        "garbled transcript '\(sample.raw)' reached destructive tier as \(result.kind)")
    }
  }

  /// Anything that *does* survive into an executable category must sit at
  /// mutation tier or above, which is what forces a confirmation prompt.
  ///
  /// `"Run and p.m. install in the terminal"` is the honest worst case: it
  /// keeps the literal `run ` prefix, so it classifies as `shellExecute`
  /// carrying nonsense. That is acceptable *only* because mutation tier shows
  /// the user the exact command before anything runs. This test fails if that
  /// intent is ever downgraded to a tier that could execute unattended.
  @Test("Executable classifications stay at confirmation-requiring tiers")
  func executableClassificationsRequireConfirmation() {
    let classifier = RuleBasedUtteranceClassifier()
    // `IntentKind` has no separate destructive shell case; destructiveness is
    // decided by the semantic category, which is exactly what is asserted.
    let executableKinds: Set<IntentKind> = [
      .shellExecute, .appTerminate, .codingAgentRun,
    ]

    for sample in Self.garbledTechnicalTranscripts {
      let result = classifier.classify(normalized: sample.normalized, raw: sample.raw)
      guard executableKinds.contains(result.kind) else { continue }
      let detail: Comment =
        "garbled transcript produced an executable intent at a tier that need not be confirmed"
      #expect(
        result.semanticCategory.riskTier == .mutation
          || result.semanticCategory.riskTier == .destructive,
        detail)
    }
  }

  /// The deterministic command table must stay an exact-match lookup.
  ///
  /// A fuzzy or edit-distance match would "helpfully" turn "Mnsa" into
  /// "npm install" and hand the user a command they never spoke. Exact
  /// matching is the property that makes a bad transcript fail closed, so it
  /// is asserted directly rather than assumed.
  @Test("Deterministic command matching never rescues a garbled transcript")
  func deterministicMatchingIsExactAndNeverFuzzy() {
    let vocabulary = UserVocabulary.bilingualTestVocabulary

    for sample in Self.garbledTechnicalTranscripts {
      #expect(
        vocabulary.matchDeterministicCommand(sample.normalized) == nil,
        "garbled transcript '\(sample.raw)' was rescued into a deterministic command")
    }

    // The table still works for what it is meant to match, so the assertion
    // above is proving exactness rather than a permanently empty table.
    #expect(vocabulary.matchDeterministicCommand("dur") == "dur")
    #expect(vocabulary.matchDeterministicCommand("cancel") == "cancel")
    // A near-miss on a real entry must also fail rather than snap to it.
    #expect(vocabulary.matchDeterministicCommand("durr") == nil)
    #expect(vocabulary.matchDeterministicCommand("cancell") == nil)
  }

  /// Turkish and English command utterances that the probe recognized cleanly
  /// must still classify correctly. Without this, the fail-closed assertions
  /// above could be satisfied by a classifier that simply rejects everything.
  @Test("Clean bilingual command transcripts still classify as commands")
  func cleanTranscriptsStillClassify() {
    let classifier = RuleBasedUtteranceClassifier()

    let safari = classifier.classify(normalized: "open safari", raw: "Open Safari")
    #expect(safari.kind == .appActivate)

    let turkishSafari = classifier.classify(
      normalized: "safariyi aç", raw: "Safari'yi aç")
    #expect(turkishSafari.kind == .appActivate)
  }
}
