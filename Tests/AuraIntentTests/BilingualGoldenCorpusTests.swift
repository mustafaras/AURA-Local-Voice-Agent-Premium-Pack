import AuraCore
import AuraIntent
import Foundation
import Testing

private struct BilingualGoldenCase: Sendable {
  let raw: String
  let normalized: String
  let expectedKind: IntentKind
  let expectedLanguage: DialogueLanguage
  let expectedAmbiguous: Bool
}

@Test
func bilingualGoldenCorpusMeetsFastPathTarget() {
  let classifier = RuleBasedUtteranceClassifier()
  let corpus = [
    BilingualGoldenCase(
      raw: "Open Safari?", normalized: "open safari", expectedKind: .appActivate,
      expectedLanguage: .english, expectedAmbiguous: false),
    BilingualGoldenCase(
      raw: "Could you open Safari?", normalized: "could you open safari",
      expectedKind: .appActivate,
      expectedLanguage: .english, expectedAmbiguous: false),
    BilingualGoldenCase(
      raw: "Lütfen Safari'yi açabilir misin?", normalized: "lütfen safariyi açabilir misin",
      expectedKind: .appActivate, expectedLanguage: .turkish, expectedAmbiguous: false),
    BilingualGoldenCase(
      raw: "Mail'i kapat", normalized: "mail'i kapat", expectedKind: .appTerminate,
      expectedLanguage: .turkish, expectedAmbiguous: false),
    BilingualGoldenCase(
      raw: "Run echo hello", normalized: "run echo hello", expectedKind: .shellExecute,
      expectedLanguage: .english, expectedAmbiguous: false),
    BilingualGoldenCase(
      raw: "Çalıştır echo merhaba", normalized: "çalıştır echo merhaba",
      expectedKind: .shellExecute,
      expectedLanguage: .turkish, expectedAmbiguous: false),
    BilingualGoldenCase(
      raw: "Çalıştır git status please", normalized: "çalıştır git status please",
      expectedKind: .unknown,
      expectedLanguage: .mixed, expectedAmbiguous: true),
    BilingualGoldenCase(
      raw: "Quit Mail", normalized: "quit mail", expectedKind: .appTerminate,
      expectedLanguage: .english, expectedAmbiguous: false),
    BilingualGoldenCase(
      raw: "What is the weather?", normalized: "what is the weather", expectedKind: .converse,
      expectedLanguage: .english, expectedAmbiguous: false),
    BilingualGoldenCase(
      raw: "Gökyüzü neden mavi?", normalized: "gökyüzü neden mavi", expectedKind: .converse,
      expectedLanguage: .turkish, expectedAmbiguous: false),
    BilingualGoldenCase(
      raw: "Please bugün hava nasıl?", normalized: "please bugün hava nasıl",
      expectedKind: .converse,
      expectedLanguage: .mixed, expectedAmbiguous: false),
  ]

  let matches = corpus.filter { goldenCase in
    let result = classifier.classify(normalized: goldenCase.normalized, raw: goldenCase.raw)
    return result.kind == goldenCase.expectedKind
      && result.language == goldenCase.expectedLanguage
      && (result.kind == .unknown ? result.confidence < 0.6 : result.confidence >= 0.6)
      && (result.kind == .unknown || !goldenCase.expectedAmbiguous)
  }

  let accuracy = Double(matches.count) / Double(corpus.count)
  #expect(accuracy >= 0.9)
  #expect(matches.count == corpus.count)
}
