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

  public init() {}

  public func classify(normalized: String, raw: String) -> ClassificationResult {
    let language = DialogueLanguage.detect(in: raw)
    var commandText = normalized
    for prefix in Self.politePrefixes where commandText.hasPrefix(prefix) {
      commandText = String(commandText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      break
    }
    if let result = classifyCodingAgent(commandText) { return result.withLanguage(language) }
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
