import AuraAgent
import Foundation
import Testing

// MARK: - Hand-written JSONL for shapes confirmed by the authorized smoke
// tests (see CopilotEventNormalizer's doc comment and
// Fixtures/copilot_smoke_quota_error*.jsonl).

@Test
func copilotNormalizerParsesSessionEvent() {
  let line = #"{"type":"session.tools_updated","data":{"model":"gpt-5-mini"}}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 1)
  #expect(event == .session(rawType: "session.tools_updated", sequence: 1))
}

@Test
func copilotNormalizerParsesUserMessage() {
  let line = #"{"type":"user.message","data":{"content":"hello there"}}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 2)
  #expect(event == .message(role: "user", content: "hello there", sequence: 2))
}

@Test
func copilotNormalizerParsesTurnStartWithModel() {
  let line = #"{"type":"assistant.turn_start","data":{"turnId":"0","model":"gpt-5-mini"}}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 3)
  #expect(event == .turnStart(turnID: "0", model: "gpt-5-mini", sequence: 3))
}

@Test
func copilotNormalizerParsesTurnStartWithoutModel() {
  // Confirmed real: fixture2's turn_start omitted "model" entirely.
  let line = #"{"type":"assistant.turn_start","data":{"turnId":"0"}}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 3)
  #expect(event == .turnStart(turnID: "0", model: nil, sequence: 3))
}

@Test
func copilotNormalizerParsesModelCallStart() {
  let line = #"{"type":"model.call_start","data":{"turnId":"0","model":"gpt-5-mini"}}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 4)
  #expect(event == .modelCallStart(model: "gpt-5-mini", sequence: 4))
}

@Test
func copilotNormalizerParsesModelCallFailure() {
  let line =
    #"{"type":"model.call_failure","data":{"model":"gpt-5-mini","statusCode":402,"errorMessage":"quota"}}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 5)
  #expect(
    event
      == .modelCallFailure(model: "gpt-5-mini", statusCode: 402, errorMessage: "quota", sequence: 5)
  )
}

@Test
func copilotNormalizerParsesSessionError() {
  let line =
    #"{"type":"session.error","data":{"errorType":"quota","errorCode":"quota_exceeded","message":"You have exceeded your monthly quota","statusCode":402}}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 6)
  #expect(
    event
      == .sessionError(
        errorType: "quota", errorCode: "quota_exceeded",
        message: "You have exceeded your monthly quota", statusCode: 402, sequence: 6))
}

@Test
func copilotNormalizerParsesAssistantIdle() {
  let event = CopilotEventNormalizer.normalize(
    line: #"{"type":"assistant.idle","data":{}}"#, sequence: 7)
  #expect(event == .assistantIdle(sequence: 7))
}

@Test
func copilotNormalizerParsesSuccessfulResult() {
  let line =
    #"{"type":"result","exitCode":0,"usage":{"premiumRequests":1,"totalApiDurationMs":500,"sessionDurationMs":1500,"codeChanges":{"linesAdded":2,"linesRemoved":1,"filesModified":["a.txt","b.txt"]}}}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 8)
  #expect(
    event
      == .turnCompleted(
        exitCode: 0, sessionDurationMs: 1500, premiumRequests: 1, filesModifiedCount: 2,
        linesAdded: 2, linesRemoved: 1))
}

@Test
func copilotNormalizerParsesFailedResult() {
  let line =
    #"{"type":"result","exitCode":1,"usage":{"premiumRequests":0,"totalApiDurationMs":0,"sessionDurationMs":1800,"codeChanges":{"linesAdded":0,"linesRemoved":0,"filesModified":[]}}}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 9)
  #expect(event == .turnFailed(message: nil))
}

@Test
func copilotNormalizerFallsBackToUnrecognizedTopLevelForUnknownType() {
  let line = #"{"type":"future.event.type"}"#
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 10)
  #expect(event == .unrecognizedTopLevel(rawType: "future.event.type", sequence: 10, rawLine: line))
}

@Test
func copilotNormalizerFallsBackToUnrecognizedForMalformedJSON() {
  let line = "not json at all"
  let event = CopilotEventNormalizer.normalize(line: line, sequence: 1)
  #expect(event == .unrecognized(rawLine: line))
}

@Test
func copilotNormalizerFallsBackToUnrecognizedForBlankLine() {
  let event = CopilotEventNormalizer.normalize(line: "   \n", sequence: 1)
  #expect(event == .unrecognized(rawLine: ""))
}

// MARK: - Fixture-based tests against real, authorized `copilot -p` output.
// Both captures hit the account's exhausted Copilot quota, which is itself
// useful real data: it exercises the full error/failure path end to end.

private func loadCopilotFixtureLines(_ name: String) throws -> [String] {
  let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")
    .appendingPathComponent(name)
  let contents = try String(contentsOf: url, encoding: .utf8)
  return contents.split(separator: "\n").map(String.init)
}

@Test
func copilotNormalizerParsesRealQuotaErrorFixtureWithoutUnrecognizedLines() throws {
  for fixtureName in ["copilot_smoke_quota_error.jsonl", "copilot_smoke_quota_error2.jsonl"] {
    let lines = try loadCopilotFixtureLines(fixtureName)
    #expect(!lines.isEmpty)

    let events = lines.enumerated().map { index, line in
      CopilotEventNormalizer.normalize(line: line, sequence: index + 1)
    }

    for event in events {
      if case .unrecognized = event {
        Issue.record("\(fixtureName): real fixture line failed to parse: \(event)")
      }
    }

    guard case .turnFailed = events.last else {
      Issue.record(
        "\(fixtureName): expected turnFailed last, got \(String(describing: events.last))")
      continue
    }

    let userMessages = events.compactMap { event -> String? in
      if case .message("user", let content, _) = event { return content }
      return nil
    }
    #expect(userMessages.count == 1, "\(fixtureName) should have exactly one user.message")

    let sessionErrors = events.compactMap { event -> String? in
      if case .sessionError(let errorType, _, _, _, _) = event { return errorType }
      return nil
    }
    #expect(
      sessionErrors == ["quota"], "\(fixtureName) should surface the real quota session.error")
  }
}
