import AuraAgent
import Foundation
import Testing

// MARK: - Hand-written JSONL for shapes confirmed by the authorized smoke
// test (see ClaudeEventNormalizer's doc comment and
// Fixtures/claude_smoke_success.jsonl).

@Test
func normalizerParsesHookStarted() {
  let line =
    #"{"type":"system","subtype":"hook_started","hook_name":"SessionStart:startup","hook_event":"SessionStart"}"#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 1)
  #expect(
    event
      == .hookEvent(
        hookName: "SessionStart:startup", hookEvent: "SessionStart", outcome: nil, sequence: 1))
}

@Test
func normalizerParsesHookResponse() {
  let line =
    #"{"type":"system","subtype":"hook_response","hook_name":"SessionStart:startup","hook_event":"SessionStart","outcome":"success"}"#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 2)
  #expect(
    event
      == .hookEvent(
        hookName: "SessionStart:startup", hookEvent: "SessionStart", outcome: "success", sequence: 2
      ))
}

@Test
func normalizerParsesSessionInit() {
  let line = #"""
    {"type":"system","subtype":"init","session_id":"abc-123","model":"claude-sonnet-4-6",
     "permissionMode":"dontAsk","tools":[],"mcp_servers":[],"claude_code_version":"2.1.195",
     "apiKeySource":"none"}
    """#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 3)
  #expect(
    event
      == .sessionInit(
        claudeSessionID: "abc-123", model: "claude-sonnet-4-6", permissionMode: "dontAsk",
        toolCount: 0, mcpServerCount: 0, claudeCodeVersion: "2.1.195", apiKeySource: "none"))
}

@Test
func normalizerParsesAssistantTextMessage() {
  let line =
    #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"ping"}]}}"#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 4)
  #expect(event == .message(role: "assistant", text: "ping", sequence: 4))
}

@Test
func normalizerCarriesNonTextContentBlocksOpaquely() {
  let line = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use"}]}}"#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 5)
  #expect(event == .unclassifiedContent(rawContentType: "tool_use", sequence: 5, rawLine: line))
}

@Test
func normalizerParsesRateLimitEvent() {
  let line =
    #"{"type":"rate_limit_event","rate_limit_info":{"status":"allowed","rateLimitType":"five_hour"}}"#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 6)
  #expect(event == .rateLimitEvent(status: "allowed", rateLimitType: "five_hour", sequence: 6))
}

@Test
func normalizerParsesSuccessfulResult() {
  let line =
    #"{"type":"result","subtype":"success","is_error":false,"result":"ping","num_turns":1,"duration_ms":1486,"stop_reason":"end_turn","total_cost_usd":0.0263853,"permission_denials":[]}"#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 7)
  #expect(
    event
      == .turnCompleted(
        resultText: "ping", totalCostUSD: 0.0263853, numTurns: 1, durationMs: 1486,
        stopReason: "end_turn", permissionDenialCount: 0))
}

@Test
func normalizerParsesFailedResult() {
  let line =
    #"{"type":"result","subtype":"error_during_execution","is_error":true,"result":"something broke","api_error_status":500}"#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 8)
  #expect(event == .turnFailed(message: "something broke", apiErrorStatus: 500))
}

@Test
func normalizerFallsBackForUndocumentedSystemSubtype() {
  let line = #"{"type":"system","subtype":"api_retry","attempt":1}"#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 9)
  #expect(event == .unrecognizedTopLevel(rawType: "system.api_retry", sequence: 9, rawLine: line))
}

@Test
func normalizerFallsBackToUnrecognizedForUnknownTopLevelType() {
  let line = #"{"type":"future_event_type"}"#
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 10)
  #expect(event == .unrecognizedTopLevel(rawType: "future_event_type", sequence: 10, rawLine: line))
}

@Test
func claudeNormalizerFallsBackToUnrecognizedForMalformedJSON() {
  let line = "not json at all"
  let event = ClaudeEventNormalizer.normalize(line: line, sequence: 1)
  #expect(event == .unrecognized(rawLine: line))
}

@Test
func claudeNormalizerFallsBackToUnrecognizedForBlankLine() {
  let event = ClaudeEventNormalizer.normalize(line: "   \n", sequence: 1)
  #expect(event == .unrecognized(rawLine: ""))
}

// MARK: - Fixture-based tests against real, authorized `claude -p` output.

private func loadFixtureLines(_ name: String) throws -> [String] {
  let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")
    .appendingPathComponent(name)
  let contents = try String(contentsOf: url, encoding: .utf8)
  return contents.split(separator: "\n").map(String.init)
}

@Test
func claudeNormalizerParsesRealSuccessfulRunFixtureWithoutUnrecognizedLines() throws {
  let lines = try loadFixtureLines("claude_smoke_success.jsonl")
  #expect(lines.count == 6)

  let events = lines.enumerated().map { index, line in
    ClaudeEventNormalizer.normalize(line: line, sequence: index + 1)
  }

  for event in events {
    if case .unrecognized = event {
      Issue.record("real fixture line failed to parse: \(event)")
    }
  }

  guard case .hookEvent = events[0] else {
    Issue.record("expected hookEvent first, got \(events[0])")
    return
  }
  guard
    case .sessionInit(_, let model, let permissionMode, let toolCount, _, _, let apiKeySource) =
      events[2]
  else {
    Issue.record("expected sessionInit third, got \(events[2])")
    return
  }
  #expect(model == "claude-sonnet-4-6")
  #expect(permissionMode == "dontAsk")
  #expect(toolCount == 0)
  #expect(apiKeySource == "none")

  let assistantTexts = events.compactMap { event -> String? in
    if case .message("assistant", let text, _) = event { return text }
    return nil
  }
  #expect(assistantTexts == ["ping"])

  guard case .turnCompleted(let resultText, let cost, let numTurns, _, _, _) = events.last else {
    Issue.record("expected turnCompleted last, got \(String(describing: events.last))")
    return
  }
  #expect(resultText == "ping")
  #expect(cost > 0)
  #expect(numTurns == 1)
}
