import Foundation

/// User-provided vocabulary hints to improve transcription of repository names,
/// contacts, commands, acronyms, and technical terms.
///
/// Vocabulary entries are split into deterministic early-command terms (used for
/// stable-segment gating) and contextual hints (passed to the engine without
/// changing the underlying language model).
public struct UserVocabulary: Sendable, Equatable, Codable {
    /// Phrases that are safe to act on before full stabilization because they
    /// are unambiguous and policy-reviewed (e.g. "stop", "cancel"). Each entry
    /// maps a normalized phrase to its canonical form.
    public var deterministicCommands: [String: String]

    /// Words or phrases that should be preferred by the engine when ambiguous.
    /// No execution guarantees are attached.
    public var contextualHints: Set<String>

    /// Locale-independent technical terms (package names, APIs, acronyms).
    public var technicalTerms: Set<String>

    public init(
        deterministicCommands: [String: String] = [:],
        contextualHints: Set<String> = [],
        technicalTerms: Set<String> = []
    ) {
        self.deterministicCommands = deterministicCommands
        self.contextualHints = contextualHints
        self.technicalTerms = technicalTerms
    }

    /// Vocabulary for tests covering Turkish/English code-switching.
    public static var bilingualTestVocabulary: UserVocabulary {
        UserVocabulary(
            deterministicCommands: [
                "dur": "dur",
                "stop": "stop",
                "iptal": "iptal",
                "cancel": "cancel",
                "aç": "aç",
                "open": "open",
                "cancel edelim": "cancel",
                "run test suite": "run test suite"
            ],
            contextualHints: [
                "AURA",
                "GitHub",
                "Copilot",
                "Codex",
                "Claude",
                "Ollama",
                "SwiftPM",
                "Xcode",
                "swiftc",
                "git push",
                "AsyncSequence"
            ],
            technicalTerms: [
                "swiftpm",
                "async/await",
                "actor",
                "NSLock",
                "SFCustomLanguageModelData",
                "GitKraken",
                "VS Code",
                "VoiceActivityDetector",
                "nonisolated(unsafe)"
            ]
        )
    }

    /// Returns the canonical form of a deterministic command if the supplied
    /// text matches after normalization, otherwise nil.
    public func matchDeterministicCommand(_ text: String) -> String? {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return deterministicCommands[normalized]
    }

    /// All contextual hints as an array for engine adapters.
    public func allContextualHints() -> [String] {
        Array(contextualHints) + Array(technicalTerms)
    }
}
