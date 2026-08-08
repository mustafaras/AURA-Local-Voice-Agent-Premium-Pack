import AuraCore
import Testing

struct TurnCompletionHeuristicsTests {
  @Test func detectsConservativeTurkishAndEnglishIncompleteForms() {
    #expect(TurnCompletionHeuristics.likelyIncomplete("run the tests and"))
    #expect(TurnCompletionHeuristics.likelyIncomplete("testleri çalıştır, "))
    #expect(TurnCompletionHeuristics.likelyIncomplete("can you check ("))
    #expect(!TurnCompletionHeuristics.likelyIncomplete("run the test suite"))
    #expect(!TurnCompletionHeuristics.likelyIncomplete("testleri çalıştır"))
  }

  @Test func ignoresBlankOrVeryShortText() {
    #expect(!TurnCompletionHeuristics.likelyIncomplete(""))
    #expect(!TurnCompletionHeuristics.likelyIncomplete("hello"))
  }
}
