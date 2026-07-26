import AuraAgent
import Testing

@Test
func reviewVerdictParserRecognizesApprove() {
  let verdict = ReviewVerdictParser.parse(
    """
    The diff looks correct and the validation passed.

    VERDICT: APPROVE
    """)
  #expect(verdict == .approve)
}

@Test
func reviewVerdictParserIsCaseInsensitive() {
  let verdict = ReviewVerdictParser.parse("Looks good.\nverdict: approve")
  #expect(verdict == .approve)
}

@Test
func reviewVerdictParserRecognizesRequestChangesWithReason() {
  let verdict = ReviewVerdictParser.parse(
    """
    The diff does not add the required test coverage.

    VERDICT: REQUEST_CHANGES: missing unit tests for the new branch
    """)
  #expect(verdict == .requestChanges(reason: "missing unit tests for the new branch"))
}

@Test
func reviewVerdictParserTreatsMissingMarkerAsUnparseable() {
  let verdict = ReviewVerdictParser.parse("This looks fine to me, ship it.")
  #expect(verdict == .unparseable)
}

@Test
func reviewVerdictParserTreatsEmptyTextAsUnparseable() {
  #expect(ReviewVerdictParser.parse("") == .unparseable)
  #expect(ReviewVerdictParser.parse("   \n\n  ") == .unparseable)
}

@Test
func reviewVerdictParserTreatsNonTrailingMarkerAsUnparseable() {
  // The marker must be the response's terminal convention, per the
  // orchestrator's own prompt instructions ("end your response with exactly
  // one line, and nothing after it") — a marker followed by more prose does
  // not count, biasing ambiguous output toward "not approved."
  let verdict = ReviewVerdictParser.parse(
    "VERDICT: APPROVE\n\nThanks for reviewing, let me know if anything else is needed.")
  #expect(verdict == .unparseable)
}

@Test
func reviewVerdictParserIgnoresApproveMentionedMidProse() {
  let verdict = ReviewVerdictParser.parse(
    "I would normally approve this, but let me check one more thing.")
  #expect(verdict == .unparseable)
}

@Test
func reviewVerdictParserRequestChangesWithEmptyReasonFallsBackToPlaceholder() {
  let verdict = ReviewVerdictParser.parse("VERDICT: REQUEST_CHANGES:   ")
  #expect(verdict == .requestChanges(reason: "no reason given"))
}

@Test
func reviewVerdictParserTrimsTrailingWhitespaceAfterApprove() {
  let verdict = ReviewVerdictParser.parse("VERDICT: APPROVE   \n\n  ")
  #expect(verdict == .approve)
}
