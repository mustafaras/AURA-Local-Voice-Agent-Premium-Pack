import AuraContext
import AuraCore
import AuraMemory
import Foundation

private struct TurkishSuffixCommand {
  let suffix: String
  let kind: IntentKind
  let category: IntentSemanticCategory
}

/// Deterministic, keyword-driven classifier over the closed v1 vocabulary —
/// no model, no network dependency, fully reproducible in tests. Every
/// resolvable app name and shell executable is drawn from a small,
/// explicit, closed lookup table; an utterance that *looks* like a command
/// but names something outside that table is deliberately classified
/// `.unknown` rather than guessing a bundle identifier or executable path.
public struct RuleBasedUtteranceClassifier: UtteranceClassifying, Sendable {
  public static let knownApplications: [String: String] = [
    "safari": "com.apple.Safari",
    "mail": "com.apple.mail",
    "posta": "com.apple.mail",
    "finder": "com.apple.finder",
    "dosyalar": "com.apple.finder",
    "terminal": "com.apple.Terminal",
    "calculator": "com.apple.calculator",
    "hesap makinesi": "com.apple.calculator",
    "notes": "com.apple.Notes",
    "notlar": "com.apple.Notes",
    "calendar": "com.apple.iCal",
    "takvim": "com.apple.iCal",
    "music": "com.apple.Music",
    "müzik": "com.apple.Music",
  ]

  public static let knownExecutables: [String: String] = [
    "echo": "/bin/echo",
    "ls": "/bin/ls",
    "pwd": "/bin/pwd",
    "date": "/bin/date",
    "whoami": "/usr/bin/whoami",
  ]

  private static let agentTriggers: [String: String] = [
    "codex ": "codex",
    "claude ": "claude",
    "copilot ": "copilot",
  ]
  private static let genericAgentTriggers = [
    "ask the coding agent to ",
    "have the coding agent ",
  ]
  private static let activatePrefixes = [
    "activate ", "open ", "launch ", "switch to ", "aç ", "başlat ",
  ]
  private static let terminatePrefixes = [
    "quit ", "terminate ", "close ", "kapat ", "sonlandır ",
  ]
  private static let shellPrefixes = ["run ", "execute ", "çalıştır ", "yürüt "]
  private static let politePrefixes = [
    "please ", "lütfen ", "could you ", "can you ", "would you ",
  ]

  // SP-005: patterns for filesystem/URL capabilities. These run BEFORE
  // `classifyAppCommand` because `"open "` is in `activatePrefixes` and
  // would otherwise swallow `"open /path/to/file.txt"` as an app-activate
  // attempt. The guard is shape-based: a target containing `/`, `~`, `://`,
  // or a file extension with a dot is a path/URL, not an app name.
  private static let fileOpenPrefixes = ["open file ", "open folder ", "open "]
  private static let fileOpenPrefixesTR = ["dosya aç ", "klasör aç ", "aç "]
  private static let revealPrefixes = [
    "reveal ", "show in finder ", "show ",
  ]
  private static let revealPrefixesTR = ["göster ", "finder'da göster "]
  private static let urlOpenPrefixes = ["open url ", "open link ", "open site ", "go to "]
  private static let urlOpenPrefixesTR = ["bağlantı aç ", "site aç ", "adrese git "]

  // SP-010: read-first productivity patterns. These run BEFORE the file/URL
  // and app classifiers because several triggers share a leading verb with
  // them — "read this page" and "show my calendar" would otherwise be
  // swallowed by `revealPrefixes`, and "open mail" by `activatePrefixes`.
  // Each trigger is an explicit multi-word phrase rather than a bare verb, so
  // "open safari" still activates the app instead of reading a tab.
  private static let browserReadTriggers = [
    "read this page", "read the current page", "read the active tab",
    "what is on this page", "summarize this page", "what does this page say",
    "bu sayfayı oku", "bu sayfada ne yazıyor", "açık sekmeyi oku",
    "geçerli sayfayı oku", "bu sayfayı özetle",
  ]
  private static let mailSearchPrefixes = [
    "search mail for ", "search my mail for ", "search email for ",
    "find mail about ", "find email about ", "look in my mail for ",
    "postada ara ", "postalarımda ara ", "e-postada ara ", "mailde ara ",
  ]
  private static let mailThreadPrefixes = [
    "summarize mail thread about ", "summarize email thread about ",
    "summarize the mail thread about ", "summarize the email thread about ",
    "posta zincirini özetle ", "e-posta zincirini özetle ", "mail zincirini özetle ",
  ]
  private static let mailUnreadTriggers = [
    "check my mail", "check my email", "do i have new mail", "any new mail",
    "postalarımı kontrol et", "yeni postam var mı", "e-postalarımı kontrol et",
  ]
  private static let calendarTodayTriggers = [
    "what is on my calendar", "what's on my calendar", "show my calendar",
    "my agenda today", "what do i have today", "check my calendar",
    "takvimimde ne var", "takvimimi göster", "bugün ne var", "ajandam ne durumda",
  ]
  private static let calendarTomorrowTriggers = [
    "what do i have tomorrow", "my agenda tomorrow", "calendar tomorrow",
    "yarın ne var", "yarınki takvimim",
  ]
  private static let contactsLookupPrefixes = [
    "find contact ", "look up contact ", "find the contact ", "contact info for ",
    "kişi bul ", "kişiyi bul ", "rehberde ara ", "kişi ara ",
  ]

  public init() {}

  public func classify(normalized: String, raw: String) -> ClassificationResult {
    let language = DialogueLanguage.detect(in: raw)
    var commandText = normalized
    for prefix in Self.politePrefixes where commandText.hasPrefix(prefix) {
      commandText = String(commandText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      break
    }
    if let result = classifyCodingAgent(commandText) { return result.withLanguage(language) }
    // SP-010: productivity reads run before file/URL and app classification;
    // see `productivityReadTriggers` for why the ordering matters.
    if let result = classifyProductivityRead(commandText) {
      return result.withLanguage(language)
    }
    // SP-005: file/URL classification runs before app-activate because
    // "open " is shared. A path-shaped target (contains /, ~, ://, or a
    // dotted extension) is routed to the filesystem/URL adapter, not the
    // app activator.
    if let result = classifyFileOrURLCommand(commandText) {
      return result.withLanguage(language)
    }
    if let result = classifyAppCommand(
      commandText, prefixes: Self.activatePrefixes, kind: .appActivate,
      category: .appActivate)
    {
      return result.withLanguage(language)
    }
    if let result = classifyAppCommand(
      commandText, prefixes: Self.terminatePrefixes, kind: .appTerminate,
      category: .appTerminate)
    {
      return result.withLanguage(language)
    }
    if let result = classifyTurkishSuffixAppCommand(commandText) {
      return result.withLanguage(language)
    }
    if let result = classifyShellCommand(commandText) { return result.withLanguage(language) }
    return ClassificationResult(
      kind: .converse,
      semanticCategory: .converse,
      confidence: 0.9,
      language: language,
      dialogueAct: .answer)
  }

  private func classifyCodingAgent(_ normalized: String) -> ClassificationResult? {
    for (prefix, backend) in Self.agentTriggers where normalized.hasPrefix(prefix) {
      let objective = String(normalized.dropFirst(prefix.count))
      guard !objective.isEmpty else { return nil }
      return ClassificationResult(
        kind: .codingAgentRun,
        semanticCategory: .codingAgentRun,
        slots: [
          IntentSlot(name: IntentSlotName.backend, value: backend),
          IntentSlot(name: IntentSlotName.objective, value: objective),
        ],
        confidence: 0.85)
    }
    for prefix in Self.genericAgentTriggers where normalized.hasPrefix(prefix) {
      let objective = String(normalized.dropFirst(prefix.count))
      guard !objective.isEmpty else { return nil }
      return ClassificationResult(
        kind: .codingAgentRun,
        semanticCategory: .codingAgentRun,
        slots: [IntentSlot(name: IntentSlotName.objective, value: objective)],
        confidence: 0.85)
    }
    return nil
  }

  // MARK: - SP-010: Read-first productivity classification

  /// Classify the four read-first productivity utterances in both languages.
  ///
  /// The classifier never resolves *which* account or profile to read: it
  /// emits only the query and range the user actually said. Account
  /// resolution belongs to `ApprovedIntegrationAccounts`, which fails closed
  /// on ambiguity — a classifier that guessed an account here would silently
  /// bypass that boundary.
  private func classifyProductivityRead(_ normalized: String) -> ClassificationResult? {
    let lowered = normalized.lowercased()

    for trigger in Self.browserReadTriggers where lowered.hasPrefix(trigger) {
      return ClassificationResult(
        kind: .browserRead,
        semanticCategory: .browserRead,
        confidence: 0.85,
        contextRequirements: ["browserProfile"])
    }

    for prefix in Self.mailThreadPrefixes where lowered.hasPrefix(prefix) {
      let query = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      guard !query.isEmpty else { return nil }
      return ClassificationResult(
        kind: .mailRead,
        semanticCategory: .mailRead,
        slots: [
          IntentSlot(name: IntentSlotName.query, value: query),
          IntentSlot(name: IntentSlotName.threadSummary, value: "true"),
        ],
        confidence: 0.85,
        contextRequirements: ["mailAccount"])
    }
    for prefix in Self.mailSearchPrefixes where lowered.hasPrefix(prefix) {
      let query = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      guard !query.isEmpty else { return nil }
      return ClassificationResult(
        kind: .mailRead,
        semanticCategory: .mailRead,
        slots: [IntentSlot(name: IntentSlotName.query, value: query)],
        confidence: 0.85,
        contextRequirements: ["mailAccount"])
    }
    for trigger in Self.mailUnreadTriggers where lowered.hasPrefix(trigger) {
      // "Check my mail" has no query, but the mail capability requires one.
      // `is:unread` is the provider's own read-only query language, not
      // caller-supplied free text, so it stays a fixed constant here.
      return ClassificationResult(
        kind: .mailRead,
        semanticCategory: .mailRead,
        slots: [IntentSlot(name: IntentSlotName.query, value: "is:unread")],
        confidence: 0.85,
        contextRequirements: ["mailAccount"])
    }

    for trigger in Self.calendarTomorrowTriggers where lowered.hasPrefix(trigger) {
      return ClassificationResult(
        kind: .calendarRead,
        semanticCategory: .calendarRead,
        slots: [IntentSlot(name: IntentSlotName.dayRange, value: "2")],
        confidence: 0.85,
        contextRequirements: ["calendarAuthorization"])
    }
    for trigger in Self.calendarTodayTriggers where lowered.hasPrefix(trigger) {
      return ClassificationResult(
        kind: .calendarRead,
        semanticCategory: .calendarRead,
        slots: [IntentSlot(name: IntentSlotName.dayRange, value: "1")],
        confidence: 0.85,
        contextRequirements: ["calendarAuthorization"])
    }

    for prefix in Self.contactsLookupPrefixes where lowered.hasPrefix(prefix) {
      let query = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      guard !query.isEmpty else { return nil }
      return ClassificationResult(
        kind: .contactsLookup,
        semanticCategory: .contactsLookup,
        slots: [IntentSlot(name: IntentSlotName.query, value: query)],
        confidence: 0.85,
        contextRequirements: ["contactsAuthorization"])
    }

    return nil
  }

  // MARK: - SP-005: Filesystem and URL classification

  /// Classify "open <path>", "reveal <path>", and "open <url>" utterances
  /// before the app-activate classifier can swallow them. The guard is
  /// shape-based: only targets that look like paths (contain `/`, `~`) or
  /// URLs (contain `://` or start with `http`/`https`/`mailto`) are routed
  /// here; bare names like "safari" fall through to `classifyAppCommand`.
  private func classifyFileOrURLCommand(_ normalized: String) -> ClassificationResult? {
    // URL detection: "open url ", "open link ", "go to ", TR variants, or
    // the target itself starts with http/https/mailto.
    for prefix in Self.urlOpenPrefixes + Self.urlOpenPrefixesTR
    where normalized.lowercased().hasPrefix(prefix) {
      let target = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      guard !target.isEmpty, looksLikeURL(target) else { return nil }
      return ClassificationResult(
        kind: .urlOpen,
        semanticCategory: .urlOpen,
        slots: [IntentSlot(name: IntentSlotName.url, value: target)],
        confidence: 0.85,
        contextRequirements: ["url"])
    }
    // Bare URL without prefix: "https://example.com"
    if looksLikeURL(normalized) && normalized.contains("://") {
      return ClassificationResult(
        kind: .urlOpen,
        semanticCategory: .urlOpen,
        slots: [IntentSlot(name: IntentSlotName.url, value: normalized)],
        confidence: 0.85,
        contextRequirements: ["url"])
    }

    // Reveal detection: "reveal <path>", "show <path>", TR "göster <path>"
    for prefix in Self.revealPrefixes + Self.revealPrefixesTR
    where normalized.lowercased().hasPrefix(prefix) {
      let target = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      guard !target.isEmpty, looksLikePath(target) else { return nil }
      return ClassificationResult(
        kind: .fileReveal,
        semanticCategory: .fileReveal,
        slots: [IntentSlot(name: IntentSlotName.filePath, value: target)],
        confidence: 0.85,
        contextRequirements: ["filePath"])
    }

    // File/folder open: "open <path>", TR "dosya aç <path>", etc.
    // Must run after URL and reveal checks, and must guard on path-shape
    // so "open safari" still routes to app-activate.
    for prefix in Self.fileOpenPrefixes + Self.fileOpenPrefixesTR
    where normalized.lowercased().hasPrefix(prefix) {
      let target = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      guard !target.isEmpty, looksLikePath(target) else { return nil }
      // Distinguish folder from file by trailing slash or "folder" prefix
      let isFolder =
        target.hasSuffix("/") || normalized.lowercased().hasPrefix("open folder ")
        || normalized.lowercased().hasPrefix("klasör aç ")
      return ClassificationResult(
        kind: .fileOpen,
        semanticCategory: .fileOpen,
        slots: [
          IntentSlot(
            name: isFolder ? IntentSlotName.folderPath : IntentSlotName.filePath,
            value: target)
        ],
        confidence: 0.85,
        contextRequirements: [isFolder ? "folderPath" : "filePath"])
    }

    return nil
  }

  /// A target looks like a filesystem path if it contains `/` or starts
  /// with `~`. This is deliberately conservative: a bare word like
  /// "safari" or "calculator" does not match and falls through to
  /// `classifyAppCommand`.
  private func looksLikePath(_ target: String) -> Bool {
    target.contains("/") || target.hasPrefix("~")
  }

  /// A target looks like a URL if it contains `://` or starts with
  /// `http:`/`https:`/`mailto:` (case-insensitive).
  private func looksLikeURL(_ target: String) -> Bool {
    let lower = target.lowercased()
    return lower.contains("://") || lower.hasPrefix("http:")
      || lower.hasPrefix("https:") || lower.hasPrefix("mailto:")
  }

  private func classifyAppCommand(
    _ normalized: String,
    prefixes: [String],
    kind: IntentKind,
    category: IntentSemanticCategory
  ) -> ClassificationResult? {
    for prefix in prefixes where normalized.hasPrefix(prefix) {
      let appName = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      guard !appName.isEmpty else { return nil }
      return appResult(
        appName: appName, kind: kind, category: category, contextRequirement: "application")
    }
    return nil
  }

  private func classifyTurkishSuffixAppCommand(_ normalized: String) -> ClassificationResult? {
    let commands: [TurkishSuffixCommand] = [
      TurkishSuffixCommand(suffix: " aç", kind: .appActivate, category: .appActivate),
      TurkishSuffixCommand(suffix: " başlat", kind: .appActivate, category: .appActivate),
      TurkishSuffixCommand(suffix: " açar mısın", kind: .appActivate, category: .appActivate),
      TurkishSuffixCommand(suffix: " açabilir misin", kind: .appActivate, category: .appActivate),
      TurkishSuffixCommand(suffix: " kapat", kind: .appTerminate, category: .appTerminate),
      TurkishSuffixCommand(suffix: " sonlandır", kind: .appTerminate, category: .appTerminate),
      TurkishSuffixCommand(suffix: " kapatır mısın", kind: .appTerminate, category: .appTerminate),
    ]
    for command in commands where normalized.hasSuffix(command.suffix) {
      let appName = String(normalized.dropLast(command.suffix.count))
        .trimmingCharacters(in: .whitespaces)
      guard !appName.isEmpty else { continue }
      return appResult(
        appName: appName,
        kind: command.kind,
        category: command.category,
        contextRequirement: "application")
    }
    return nil
  }

  private func appResult(
    appName: String,
    kind: IntentKind,
    category: IntentSemanticCategory,
    contextRequirement: String
  ) -> ClassificationResult {
    let normalizedName = normalizeApplicationName(appName)
    if let bundleID = Self.knownApplications[normalizedName] {
      return ClassificationResult(
        kind: kind,
        semanticCategory: category,
        slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: bundleID)],
        confidence: 0.85,
        contextRequirements: [contextRequirement])
    }
    return ClassificationResult(
      kind: .unknown,
      semanticCategory: .unknown,
      slots: [IntentSlot(name: IntentSlotName.unresolvedAppName, value: appName)],
      confidence: 0.3,
      proposedKind: kind,
      ambiguityReasons: ["application target is not registered"],
      contextRequirements: [contextRequirement])
  }

  private func normalizeApplicationName(_ name: String) -> String {
    var value =
      name
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: .punctuationCharacters)
      .replacingOccurrences(of: "'", with: "")
    for suffix in ["yi", "yı", "yu", "yü", "i", "ı", "u", "ü"] where value.hasSuffix(suffix) {
      let candidate = String(value.dropLast(suffix.count))
      if Self.knownApplications[candidate] != nil {
        value = candidate
        break
      }
    }
    return value
  }

  private func classifyShellCommand(_ normalized: String) -> ClassificationResult? {
    for prefix in Self.shellPrefixes where normalized.hasPrefix(prefix) {
      let remainder = String(normalized.dropFirst(prefix.count)).trimmingCharacters(
        in: .whitespaces)
      guard !remainder.isEmpty else { return nil }
      let tokens = remainder.split(whereSeparator: \.isWhitespace).map(String.init)
      guard let first = tokens.first else { return nil }
      let arguments = Array(tokens.dropFirst())
      let executable = first.hasPrefix("/") ? first : Self.knownExecutables[first]
      guard let resolvedExecutable = executable else {
        return ClassificationResult(
          kind: .unknown,
          semanticCategory: .unknown,
          slots: [IntentSlot(name: IntentSlotName.executable, value: first)],
          confidence: 0.3,
          proposedKind: .shellExecute,
          ambiguityReasons: ["executable is not registered"],
          contextRequirements: ["executable"])
      }
      return ClassificationResult(
        kind: .shellExecute,
        semanticCategory: .shellExecute,
        slots: [
          IntentSlot(name: IntentSlotName.executable, value: resolvedExecutable),
          IntentSlot(name: IntentSlotName.arguments, value: arguments.joined(separator: " ")),
        ],
        confidence: 0.85,
        contextRequirements: ["executable"])
    }
    return nil
  }
}
