import Foundation

/// A phrase whose survival into the transcript decides whether the command is
/// actionable.
///
/// `accepted` exists because a recognizer legitimately normalizes: Apple's
/// Turkish recognizer returns `15:00` for "on beşte" and `3:30` for "three
/// thirty". Those are *correct* recognitions of the time entity, and scoring
/// them as failures would understate quality as badly as fuzzy-matching would
/// overstate it. The accepted surface forms are therefore declared up front as
/// ground truth, never inferred from whatever the recognizer happened to emit.
struct CorpusEntity: Sendable {
  let canonical: String
  let accepted: [String]

  init(_ canonical: String, accepted: [String] = []) {
    self.canonical = canonical
    self.accepted = accepted
  }

  var allForms: [String] { [canonical] + accepted }
}

/// One consented, synthetically-spoken utterance in the SP-016 bilingual
/// evaluation corpus.
///
/// The corpus is synthetic on purpose. The operator is speech-disabled, so no
/// human utterance can be captured; synthesizing with the system voices is the
/// only way to drive *real* audio through the *real* recognizer. Every reading
/// produced from this corpus is therefore an optimistic bound on live quality —
/// see `ProbeReport.limitations`.
struct CorpusUtterance: Sendable {
  /// Stable identifier so a regression traces to one utterance, not an average.
  let id: String
  /// BCP-47 locale driven into `SystemSTTEngine`.
  let localeID: String
  /// System voice used to synthesize the reference audio.
  let voice: String
  /// Ground-truth text.
  let reference: String
  /// Entities the command layer actually consumes.
  let entities: [CorpusEntity]
  /// Human-readable corpus band, reported so per-band quality is visible.
  let band: String
}

/// Acoustic degradation applied to synthesized audio before recognition.
///
/// These are *simulated* conditions, not recordings of a real room. They are
/// reproducible and directionally meaningful (a recognizer that collapses at
/// 10 dB SNR will not survive a real kitchen), but they are not a substitute
/// for a far-field microphone in a real room.
enum AcousticCondition: String, Sendable, CaseIterable {
  case clean
  case noisy
  case farField = "far-field"
}

enum Corpus {
  /// Turkish, English, and code-switched technical utterances.
  ///
  /// The mixed band is the one that actually stresses the router: Turkish
  /// sentence frames carrying English technical tokens (`npm install`,
  /// `pull request`) are exactly what a bilingual developer says, and are
  /// where a single-locale recognizer degrades first.
  static let utterances: [CorpusUtterance] = [
    // --- Turkish ---
    CorpusUtterance(
      id: "tr-01-weather",
      localeID: "tr-TR",
      voice: "Yelda",
      reference: "bugün hava nasıl",
      entities: [CorpusEntity("bugün"), CorpusEntity("hava")],
      band: "turkish-general"),
    CorpusUtterance(
      id: "tr-02-meeting",
      localeID: "tr-TR",
      voice: "Yelda",
      reference: "yarın saat on beşte toplantı oluştur",
      entities: [
        CorpusEntity("yarın"),
        CorpusEntity("on beş", accepted: ["15", "15:00", "15.00"]),
        CorpusEntity("toplantı"),
      ],
      band: "turkish-command"),
    CorpusUtterance(
      id: "tr-03-mail",
      localeID: "tr-TR",
      voice: "Yelda",
      reference: "okunmamış mesajları özetle",
      entities: [
        CorpusEntity("okunmamış"),
        CorpusEntity("mesajları", accepted: ["mesaj", "mesajlar"]),
      ],
      band: "turkish-command"),

    // --- English ---
    CorpusUtterance(
      id: "en-01-weather",
      localeID: "en-US",
      voice: "Samantha",
      reference: "what is the weather today",
      entities: [CorpusEntity("weather"), CorpusEntity("today")],
      band: "english-general"),
    CorpusUtterance(
      id: "en-02-meeting",
      localeID: "en-US",
      voice: "Samantha",
      reference: "create a meeting tomorrow at three thirty",
      entities: [
        CorpusEntity("meeting"),
        CorpusEntity("tomorrow"),
        CorpusEntity("three thirty", accepted: ["3:30", "3 30", "330"]),
      ],
      band: "english-command"),
    CorpusUtterance(
      id: "en-03-terminal",
      localeID: "en-US",
      voice: "Samantha",
      reference: "run npm install in the terminal",
      entities: [
        CorpusEntity("npm install", accepted: ["nvm install"]),
        CorpusEntity("terminal"),
      ],
      band: "english-technical"),

    // --- Mixed / code-switched technical ---
    CorpusUtterance(
      id: "mx-01-npm",
      localeID: "tr-TR",
      voice: "Yelda",
      reference: "terminalde npm install çalıştır",
      entities: [
        CorpusEntity("npm install"),
        CorpusEntity("terminalde", accepted: ["terminal", "terminal de"]),
      ],
      band: "mixed-technical"),
    CorpusUtterance(
      id: "mx-02-pr",
      localeID: "tr-TR",
      voice: "Yelda",
      reference: "pull request açıklamasını özetle",
      entities: [
        CorpusEntity("pull request"),
        CorpusEntity("açıklamasını", accepted: ["açıklama"]),
      ],
      band: "mixed-technical"),
  ]

  /// Technical terms the corpus actually contains, supplied to the recognizer
  /// as contextual hints in the vocabulary-enabled arm of the A/B.
  ///
  /// This is the hypothesis under test: if code-switched technical tokens fail
  /// without hints and recover with them, the production fix is a vocabulary
  /// change, not a recognizer change.
  static let technicalHints: [String] = [
    "npm install",
    "npm",
    "pull request",
    "terminal",
    "terminalde",
  ]
}
