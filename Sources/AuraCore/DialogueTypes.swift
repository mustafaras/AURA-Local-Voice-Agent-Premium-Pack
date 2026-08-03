import Foundation

public enum DialogueLanguage: String, Codable, Sendable, Equatable, CaseIterable {
  case turkish
  case english
  case mixed
  case unknown

  public var ttsLocale: String {
    switch self {
    case .turkish: return "tr-TR"
    case .english: return "en-US"
    case .mixed, .unknown: return "tr-TR"
    }
  }

  public static func detect(in text: String) -> DialogueLanguage {
    let tokens = Set(
      text.lowercased()
        .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
        .map(String.init))
    let turkishSignals: Set<String> = [
      "aç", "açık", "başlat", "bugün", "bu", "çalıştır", "dosya", "et", "hangi", "için",
      "kapat", "lütfen", "merhaba", "mi", "mı", "mu", "mü", "nasıl", "ne", "neden", "notlar",
      "posta", "sürdür", "teşekkür", "yardım"
    ]
    let englishSignals: Set<String> = [
      "a", "about", "activate", "and", "close", "execute", "file", "for", "hello", "how",
      "is", "launch", "open", "please", "quit", "run", "the", "what", "why"
    ]
    let turkishCount = tokens.intersection(turkishSignals).count
    let englishCount = tokens.intersection(englishSignals).count
    switch (turkishCount > 0, englishCount > 0) {
    case (true, true): return .mixed
    case (true, false): return .turkish
    case (false, true): return .english
    default: return .unknown
    }
  }
}

public enum DialogueAct: String, Codable, Sendable, Equatable, CaseIterable {
  case answer
  case execute
  case clarify
  case confirm
  case delegate
  case cancel
}

public struct DialogueContextItem: Codable, Sendable, Equatable {
  public let sourceID: String
  public let summary: String
  public let confidence: Double
  public let authority: String

  public init(
    sourceID: String,
    summary: String,
    confidence: Double,
    authority: String
  ) {
    self.sourceID = sourceID
    self.summary = summary
    self.confidence = min(max(confidence, 0), 1)
    self.authority = authority
  }
}

public struct DialogueResponse: Codable, Sendable, Equatable {
  public let text: String
  public let language: DialogueLanguage
  public let dialogueAct: DialogueAct
  public let modelID: String?
  public let degraded: Bool
  public let sourceIDs: [String]

  public init(
    text: String,
    language: DialogueLanguage,
    dialogueAct: DialogueAct = .answer,
    modelID: String? = nil,
    degraded: Bool,
    sourceIDs: [String] = []
  ) {
    self.text = text
    self.language = language
    self.dialogueAct = dialogueAct
    self.modelID = modelID
    self.degraded = degraded
    self.sourceIDs = sourceIDs
  }
}

public struct StructuredNLUResponse: Codable, Sendable, Equatable {
  public let dialogueAct: String
  public let language: String
  public let capabilityID: String
  public let confidence: String
  public let ambiguityReason: String

  public init(
    dialogueAct: String,
    language: String,
    capabilityID: String,
    confidence: String,
    ambiguityReason: String
  ) {
    self.dialogueAct = dialogueAct
    self.language = language
    self.capabilityID = capabilityID
    self.confidence = confidence
    self.ambiguityReason = ambiguityReason
  }
}
