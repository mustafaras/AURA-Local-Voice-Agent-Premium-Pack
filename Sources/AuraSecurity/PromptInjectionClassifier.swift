import AuraCore
import Foundation

/// Ranked severity of one matched injection indicator. Values are chosen so
/// summing them produces a meaningful cumulative score: a single `.high`
/// match (4) exceeds the default block threshold (3) on its own, two
/// `.medium` matches (2 + 2) also exceed it, and a single `.low` or
/// `.medium` match alone does not — it is merely flagged `.suspicious`.
public enum InjectionSeverity: Int, Codable, Sendable, Equatable, Comparable, CaseIterable {
  case low = 1
  case medium = 2
  case high = 4

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One matched injection indicator.
public struct InjectionSignal: Sendable, Equatable {
  public let ruleID: String
  public let category: String
  public let severity: InjectionSeverity
  /// Up to 120 characters of the matched text, for audit/debugging — never
  /// the full untrusted document, to keep audit events bounded.
  public let matchedSnippet: String
}

/// Result of classifying one piece of untrusted content.
public enum InjectionVerdict: Sendable, Equatable {
  case clean
  case suspicious(signals: [InjectionSignal])
  case blocked(signals: [InjectionSignal])

  public var signals: [InjectionSignal] {
    switch self {
    case .clean: return []
    case .suspicious(let signals), .blocked(let signals): return signals
    }
  }

  public var isBlocked: Bool {
    if case .blocked = self { return true }
    return false
  }
}

private struct InjectionRule {
  let id: String
  let category: String
  let severity: InjectionSeverity
  let pattern: String
}

/// Deterministic, rule-based prompt-injection classifier implementing
/// `docs/security/28_PROMPT_INJECTION_DEFENSE.md`'s "dedicated security
/// classifier plus deterministic rules" defense.
///
/// This is deliberately not a model-based classifier: a second LLM call to
/// judge injection risk would itself be exposed to the same untrusted text,
/// and its judgment would not be reproducible or auditable the way a fixed
/// rule set is. `classify(_:provenance:)` only ever inspects content whose
/// `ContentProvenance.carriesAuthority` is `false` — per the security
/// model's core rule, authoritative content (the live user, AURA's own
/// policy) cannot be "injected" into itself, so it is never scanned and
/// never scored as suspicious.
public struct PromptInjectionClassifier: Sendable {
  private let enabled: Bool
  private let blockSeverityThreshold: Int
  private let compiledRules: [(rule: InjectionRule, regex: NSRegularExpression)]

  public init(configuration: SecurityConfiguration = SecurityConfiguration()) {
    self.enabled = configuration.injectionClassifierEnabled
    self.blockSeverityThreshold = configuration.injectionBlockSeverityThreshold
    self.compiledRules = Self.defaultRules.compactMap { rule in
      guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive])
      else { return nil }
      return (rule, regex)
    }
  }

  /// Classify `text` sourced from `provenance`. Content whose provenance
  /// `carriesAuthority` is never scanned and always returns `.clean`.
  public func classify(_ text: String, provenance: ContentProvenance) -> InjectionVerdict {
    guard enabled, !provenance.carriesAuthority, !text.isEmpty else { return .clean }

    let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
    var signals: [InjectionSignal] = []
    for (rule, regex) in compiledRules {
      guard let match = regex.firstMatch(in: text, options: [], range: fullRange),
        let matchedRange = Range(match.range, in: text)
      else { continue }
      signals.append(
        InjectionSignal(
          ruleID: rule.id,
          category: rule.category,
          severity: rule.severity,
          matchedSnippet: String(text[matchedRange].prefix(120))
        ))
    }

    guard !signals.isEmpty else { return .clean }
    let totalSeverity = signals.reduce(0) { $0 + $1.severity.rawValue }
    return totalSeverity >= blockSeverityThreshold ? .blocked(signals: signals) : .suspicious(signals: signals)
  }

  // MARK: - Rule set

  /// Adversarial categories covered, matching `docs/security/
  /// 28_PROMPT_INJECTION_DEFENSE.md`'s "Tests" section (webpages, README
  /// files, terminal output, issue text, PDFs, image text — all of which
  /// arrive as plain extracted text by the time they reach this classifier).
  private static let defaultRules: [InjectionRule] = [
    InjectionRule(
      id: "instructionOverride.ignorePrevious", category: "instructionOverride", severity: .high,
      pattern: "ignore (all|any|the)?\\s*(previous|prior|above|earlier)\\s*(instructions|rules|prompt)"
    ),
    InjectionRule(
      id: "instructionOverride.disregard", category: "instructionOverride", severity: .high,
      pattern: "disregard (your|the|all)\\s*(instructions|rules|policy|guidelines)"),
    InjectionRule(
      id: "instructionOverride.forget", category: "instructionOverride", severity: .medium,
      pattern: "forget (everything|what) (you were|i) (told|said)"),
    InjectionRule(
      id: "instructionOverride.nonEnglishIgnore", category: "instructionOverride", severity: .medium,
      pattern: "(ignorez|ignorer|ignora|ignoriere|ignoriert|игнорируйте|無視)\\s.*(instructions|instrucciones|istruzioni|anweisungen|инструкции|命令|指示)"),
    InjectionRule(
      id: "roleHijack.youAreNow", category: "roleHijack", severity: .high,
      pattern: "you are now (a|an) "),
    InjectionRule(
      id: "roleHijack.pretend", category: "roleHijack", severity: .medium,
      pattern: "pretend (you are|to be)"),
    InjectionRule(
      id: "roleHijack.newSystemPrompt", category: "roleHijack", severity: .high,
      pattern: "new system prompt"),
    InjectionRule(
      id: "roleHijack.systemPrefix", category: "roleHijack", severity: .medium,
      pattern: "(^|\\n)\\s*system\\s*:\\s*\\S"),
    InjectionRule(
      id: "promptExfiltration.reveal", category: "promptExfiltration", severity: .high,
      pattern: "(reveal|print|show|repeat) (your|the) (system prompt|instructions|prompt)"),
    InjectionRule(
      id: "promptExfiltration.repeatAbove", category: "promptExfiltration", severity: .medium,
      pattern: "repeat everything above"),
    InjectionRule(
      id: "credentialExfiltration.sendTo", category: "credentialExfiltration", severity: .high,
      pattern:
        "(send|email|post|forward) (this|the|your) (api key|password|token|secret|credentials?) to"
    ),
    InjectionRule(
      id: "unsanctionedExecution.runFollowing", category: "unsanctionedExecution", severity: .high,
      pattern: "run the following (command|script)"),
    InjectionRule(
      id: "unsanctionedExecution.curlPipeShell", category: "unsanctionedExecution", severity: .high,
      pattern: "curl[^\\n]{0,80}\\|\\s*(sh|bash|zsh)"),
    InjectionRule(
      id: "unsanctionedExecution.downloadAndRun", category: "unsanctionedExecution",
      severity: .medium, pattern: "download and (run|execute)"),
    InjectionRule(
      id: "authorityBypass.autoApprove", category: "authorityBypass", severity: .high,
      pattern: "(auto-?approve|skip confirmation|bypass (the )?policy)"),
    InjectionRule(
      id: "authorityBypass.withoutApproval", category: "authorityBypass", severity: .medium,
      pattern: "without (asking|confirming|approval)"),
    InjectionRule(
      id: "hiddenInstruction.zeroWidth", category: "hiddenInstruction", severity: .medium,
      pattern: "[\\u200B\\u200C\\u200D\\uFEFF]"),
    InjectionRule(
      id: "hiddenInstruction.htmlComment", category: "hiddenInstruction", severity: .medium,
      pattern: "<!--[\\s\\S]{0,10}(ignore|system|instruction)[\\s\\S]{0,200}-->"),
    InjectionRule(
      id: "dataExfiltration.forwardConversation", category: "dataExfiltration", severity: .high,
      pattern: "forward (this|the) conversation to"),
    InjectionRule(
      id: "concealment.doNotTellUser", category: "concealment", severity: .high,
      pattern: "(do not|don't) tell the user"),
    InjectionRule(
      id: "concealment.withoutInformingUser", category: "concealment", severity: .high,
      pattern: "without (informing|telling) the user"),
    InjectionRule(
      id: "concealment.keepSecretFromUser", category: "concealment", severity: .medium,
      pattern: "keep this (secret|hidden) from the user"),
  ]
}
