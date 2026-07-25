import AuraAgent
import Foundation
import Testing

// MARK: - Hand-written JSONL for shapes confirmed by official documentation
// or by the authorized smoke test (see CodexEventNormalizer's doc comment
// and Fixtures/codex_smoke_success.jsonl / codex_smoke_quota_error.jsonl).

@Test
func normalizerParsesThreadStartedWithThreadID() {
  let line = #"{"type":"thread.started","thread_id":"019f9911-9321-7051-9778-2d8e50cd73dc"}"#
  let event = CodexEventNormalizer.normalize(line: line, sequence: 1)
  #expect(event == .threadStarted(threadID: "019f9911-9321-7051-9778-2d8e50cd73dc"))
}

@Test
func normalizerParsesTurnStarted() {
  let event = CodexEventNormalizer.normalize(line: #"{"type":"turn.started"}"#, sequence: 1)
  #expect(event == .turnStarted)
}

@Test
func normalizerParsesTurnCompletedWithUsage() {
  let line = #"{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}"#
  let event = CodexEventNormalizer.normalize(line: line, sequence: 1)
  guard case .turnCompleted(let usage) = event else {
    Issue.record("expected turnCompleted, got \(event)")
    return
  }
  #expect(usage["input_tokens"] == 10)
  #expect(usage["output_tokens"] == 5)
}

@Test
func normalizerParsesTurnCompletedWithoutUsage() {
  let event = CodexEventNormalizer.normalize(line: #"{"type":"turn.completed"}"#, sequence: 1)
  guard case .turnCompleted(let usage) = event else {
    Issue.record("expected turnCompleted, got \(event)")
    return
  }
  #expect(usage.isEmpty)
}

@Test
func normalizerParsesTurnFailedFromNestedErrorMessage() {
  // Confirmed nested shape from the real quota-limit smoke test:
  // {"type":"turn.failed","error":{"message":"..."}}
  let line = #"{"type":"turn.failed","error":{"message":"boom"}}"#
  let event = CodexEventNormalizer.normalize(line: line, sequence: 1)
  #expect(event == .turnFailed(message: "boom"))
}

@Test
func normalizerParsesAgentMessageItem() {
  let line = #"{"type":"item.completed","item":{"id":"item_3","type":"agent_message","text":"ping"}}"#
  let event = CodexEventNormalizer.normalize(line: line, sequence: 4)
  #expect(event == .agentText(role: "agent_message", text: "ping", sequence: 4))
}

@Test
func normalizerParsesReasoningItem() {
  let line = #"{"type":"item.completed","item":{"id":"item_2","type":"reasoning","text":"thinking"}}"#
  let event = CodexEventNormalizer.normalize(line: line, sequence: 3)
  #expect(event == .agentText(role: "reasoning", text: "thinking", sequence: 3))
}

@Test
func normalizerParsesItemLevelError() {
  let line = #"{"type":"item.completed","item":{"id":"item_0","type":"error","message":"degraded"}}"#
  let event = CodexEventNormalizer.normalize(line: line, sequence: 1)
  #expect(event == .itemError(message: "degraded", sequence: 1))
}

@Test
func normalizerCarriesUndocumentedItemTypesOpaquely() {
  // file_change / command_execution / plan_update are named in Codex's
  // documentation but were not observed in the authorized smoke test, so
  // they must not be given fabricated structured fields.
  let line = #"{"type":"item.completed","item":{"id":"item_5","type":"file_change"}}"#
  let event = CodexEventNormalizer.normalize(line: line, sequence: 6)
  #expect(event == .unclassifiedItem(rawItemType: "file_change", sequence: 6, rawLine: line))
}

@Test
func normalizerParsesTopLevelError() {
  let line = #"{"type":"error","message":"launch failed"}"#
  let event = CodexEventNormalizer.normalize(line: line, sequence: 1)
  #expect(event == .codexError(message: "launch failed"))
}

@Test
func normalizerFallsBackToUnrecognizedForUnknownType() {
  let line = #"{"type":"future.event.type"}"#
  let event = CodexEventNormalizer.normalize(line: line, sequence: 1)
  #expect(event == .unrecognized(rawLine: line))
}

@Test
func normalizerFallsBackToUnrecognizedForMalformedJSON() {
  let line = "not json at all"
  let event = CodexEventNormalizer.normalize(line: line, sequence: 1)
  #expect(event == .unrecognized(rawLine: line))
}

@Test
func normalizerFallsBackToUnrecognizedForBlankLine() {
  let event = CodexEventNormalizer.normalize(line: "   \n", sequence: 1)
  #expect(event == .unrecognized(rawLine: ""))
}

// MARK: - Fixture-based tests against real, authorized `codex exec --json`
// output (see Tests/AuraAgentTests/Fixtures/).

private func loadFixtureLines(_ name: String) throws -> [String] {
  let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")
    .appendingPathComponent(name)
  let contents = try String(contentsOf: url, encoding: .utf8)
  return contents.split(separator: "\n").map(String.init)
}

@Test
func normalizerParsesRealSuccessfulRunFixtureWithoutUnrecognizedLines() throws {
  let lines = try loadFixtureLines("codex_smoke_success.jsonl")
  #expect(lines.count == 7)

  let events = lines.enumerated().map { index, line in
    CodexEventNormalizer.normalize(line: line, sequence: index + 1)
  }

  for event in events {
    if case .unrecognized = event {
      Issue.record("real fixture line failed to parse: \(event)")
    }
  }

  guard case .threadStarted(let threadID) = events[0] else {
    Issue.record("expected threadStarted first, got \(events[0])")
    return
  }
  #expect(threadID != nil)

  guard case .turnCompleted(let usage) = events.last else {
    Issue.record("expected turnCompleted last, got \(String(describing: events.last))")
    return
  }
  #expect(usage["input_tokens"] != nil)
  #expect(usage["output_tokens"] == 13)

  let agentMessages = events.compactMap { event -> String? in
    if case .agentText("agent_message", let text, _) = event { return text }
    return nil
  }
  #expect(agentMessages == ["ping"])
}

@Test
func normalizerParsesRealQuotaErrorFixture() throws {
  let lines = try loadFixtureLines("codex_smoke_quota_error.jsonl")
  let events = lines.enumerated().map { index, line in
    CodexEventNormalizer.normalize(line: line, sequence: index + 1)
  }

  guard case .turnFailed(let message) = events.last else {
    Issue.record("expected turnFailed last, got \(String(describing: events.last))")
    return
  }
  #expect(message?.contains("usage limit") == true)

  let topLevelErrors = events.compactMap { event -> String? in
    if case .codexError(let message) = event { return message }
    return nil
  }
  #expect(topLevelErrors.count == 1)
}
