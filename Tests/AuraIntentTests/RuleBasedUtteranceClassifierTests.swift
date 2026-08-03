import AuraCore
import AuraIntent
import Foundation
import Testing

private let classifier = RuleBasedUtteranceClassifier()

@Test
func classifierRecognizesKnownAppActivate() {
  let result = classifier.classify(normalized: "activate safari", raw: "activate safari")
  #expect(result.kind == .appActivate)
  #expect(result.semanticCategory == .appActivate)
  #expect(result.slots.first { $0.name == IntentSlotName.bundleIdentifier }?.value == "com.apple.Safari")
  #expect(result.confidence >= 0.6)
}

@Test
func classifierRecognizesOpenAsActivateSynonym() {
  let result = classifier.classify(normalized: "open mail", raw: "open mail")
  #expect(result.kind == .appActivate)
  #expect(result.slots.first { $0.name == IntentSlotName.bundleIdentifier }?.value == "com.apple.mail")
}

@Test
func classifierRecognizesTurkishApplicationCommandAndLanguage() {
  let result = classifier.classify(normalized: "safariyi aç", raw: "Safari'yi aç")
  #expect(result.kind == .appActivate)
  #expect(result.language == .turkish)
  #expect(result.dialogueAct == .execute)
  #expect(result.slots.first { $0.name == IntentSlotName.bundleIdentifier }?.value == "com.apple.Safari")
}

@Test
func classifierRecognizesMixedTechnicalQuestion() {
  let result = classifier.classify(
    normalized: "çalıştır git status please", raw: "Çalıştır git status please")
  #expect(result.language == .mixed)
  #expect(result.kind == .unknown)
  #expect(result.dialogueAct == .clarify)
  #expect(result.ambiguityReasons.contains("executable is not registered"))
}

@Test
func classifierHandlesPoliteEnglishParaphrase() {
  let result = classifier.classify(
    normalized: "could you open safari", raw: "Could you open Safari?")
  #expect(result.kind == .appActivate)
  #expect(result.language == .english)
  #expect(result.slots.first?.value == "com.apple.Safari")
}

@Test
func classifierHandlesPoliteTurkishParaphrase() {
  let result = classifier.classify(
    normalized: "lütfen safariyi açabilir misin", raw: "Lütfen Safari'yi açabilir misin?")
  #expect(result.kind == .appActivate)
  #expect(result.language == .turkish)
  #expect(result.slots.first?.value == "com.apple.Safari")
}

@Test
func classifierRecognizesKnownAppTerminate() {
  let result = classifier.classify(normalized: "quit safari", raw: "quit safari")
  #expect(result.kind == .appTerminate)
  #expect(result.semanticCategory == .appTerminate)
  #expect(result.slots.first { $0.name == IntentSlotName.bundleIdentifier }?.value == "com.apple.Safari")
}

@Test
func classifierMarksUnknownAppNameAsUnknownNotGuessed() {
  let result = classifier.classify(
    normalized: "activate some totally made up app", raw: "activate some totally made up app")
  #expect(result.kind == .unknown)
  #expect(result.confidence < 0.6)
  #expect(result.slots.first { $0.name == IntentSlotName.unresolvedAppName } != nil)
}

@Test
func classifierRecognizesKnownShellCommand() {
  let result = classifier.classify(normalized: "run echo hello world", raw: "run echo hello world")
  #expect(result.kind == .shellExecute)
  #expect(result.slots.first { $0.name == IntentSlotName.executable }?.value == "/bin/echo")
  #expect(result.slots.first { $0.name == IntentSlotName.arguments }?.value == "hello world")
}

@Test
func classifierAcceptsAbsolutePathDirectly() {
  let result = classifier.classify(normalized: "run /usr/bin/true", raw: "run /usr/bin/true")
  #expect(result.kind == .shellExecute)
  #expect(result.slots.first { $0.name == IntentSlotName.executable }?.value == "/usr/bin/true")
}

@Test
func classifierMarksUnknownExecutableAsUnknownNotGuessed() {
  let result = classifier.classify(
    normalized: "run some-random-binary --flag", raw: "run some-random-binary --flag")
  #expect(result.kind == .unknown)
  #expect(result.confidence < 0.6)
}

@Test
func classifierRecognizesNamedCodingAgentBackend() {
  let result = classifier.classify(
    normalized: "codex fix the failing test", raw: "codex fix the failing test")
  #expect(result.kind == .codingAgentRun)
  #expect(result.slots.first { $0.name == IntentSlotName.backend }?.value == "codex")
  #expect(result.slots.first { $0.name == IntentSlotName.objective }?.value == "fix the failing test")
}

@Test
func classifierRecognizesGenericCodingAgentTrigger() {
  let result = classifier.classify(
    normalized: "ask the coding agent to add a test", raw: "ask the coding agent to add a test")
  #expect(result.kind == .codingAgentRun)
  #expect(result.slots.first { $0.name == IntentSlotName.objective }?.value == "add a test")
  #expect(result.slots.first { $0.name == IntentSlotName.backend } == nil)
}

@Test
func classifierFallsBackToConverseForOrdinaryText() {
  let result = classifier.classify(
    normalized: "what's the weather like today", raw: "what's the weather like today")
  #expect(result.kind == .converse)
  #expect(result.semanticCategory == .converse)
  #expect(result.confidence >= 0.6)
}
