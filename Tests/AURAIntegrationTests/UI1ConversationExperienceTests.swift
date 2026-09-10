import AuraCore
import SwiftUI
import Testing

@testable import AURA

/// UI-1 G1-2/G1-3/G1-5/G1-6: conversation experience unit pins — markdown
/// inline-only rendering with the verbatim fallback, draft-bubble and
/// thinking-placeholder copy/a11y contract, and the Orb's pure state→layer
/// mapping across all six behaviors.
struct UI1ConversationExperienceTests {

  // MARK: - G1-2 Markdown

  @Test("markdown: bold, italic, and inline code render as presentation intents")
  func inlineIntentsRender() {
    let bold = AuraDesign.inlineMarkdownOrPlain("**bold**")
    #expect(
      bold.runs.contains {
        $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
      })
    #expect(String(bold.characters) == "bold")

    let italic = AuraDesign.inlineMarkdownOrPlain("*it*")
    #expect(
      italic.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
    #expect(String(italic.characters) == "it")

    let code = AuraDesign.inlineMarkdownOrPlain("`code`")
    #expect(code.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
    #expect(String(code.characters) == "code")
  }

  @Test("markdown: links render with a link attribute, content preserved")
  func linksRender() {
    let attr = AuraDesign.inlineMarkdownOrPlain("[site](https://example.com)")
    #expect(String(attr.characters) == "site")
    #expect(attr.runs.contains { $0.link?.absoluteString == "https://example.com" })
  }

  @Test("markdown: block syntax degrades to plain text (inline-only verified)")
  func blockSyntaxStaysInline() {
    // Headings, lists, and fences carry no block semantics under the
    // inline-only interpretation; their glyphs pass through as text and no
    // run gains a block-level attribute.
    let heading = AuraDesign.inlineMarkdownOrPlain("# Heading")
    #expect(String(heading.characters) == "# Heading")
    #expect(heading.runs.allSatisfy { $0.inlinePresentationIntent == nil })

    let list = AuraDesign.inlineMarkdownOrPlain("- item one")
    #expect(String(list.characters) == "- item one")

    // Fenced code collapses to a code-intent run, never a block view.
    let fence = AuraDesign.inlineMarkdownOrPlain("```swift\nlet x = 1\n```")
    #expect(fence.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
  }

  @Test("markdown: malformed input falls back to raw text verbatim (never dropped)")
  func malformedInputFallsBackVerbatim() throws {
    // The pinned fallback cases (G1-2): whatever the parser refuses, the
    // caller must see the exact original characters.
    let cases = [
      "**unclosed bold",
      "[broken](",
      "[unclosed ref][x]",
      "`unclosed code",
    ]
    for markdown in cases {
      #expect(
        String(AuraDesign.inlineMarkdownOrPlain(markdown).characters) == markdown,
        "fallback must return the raw text verbatim for \(markdown)")
    }
  }

  @Test("markdown: parsing options are inline-only, whitespace-preserving")
  func parsingOptionsPinned() {
    #expect(
      AuraDesign.markdownParsingOptions.interpretedSyntax
        == .inlineOnlyPreservingWhitespace)
  }

  // MARK: - G1-3 Draft bubble + G1-5 thinking placeholder (copy contract)

  @Test("draft bubble copy keys resolve in both languages")
  func draftCopyKeysResolve() {
    #expect(AuraCopy.text("a11y.draftPrefix", language: .english) == "Draft")
    #expect(AuraCopy.text("a11y.draftPrefix", language: .turkish) == "Taslak")
  }

  @Test("thinking placeholder copy keys resolve in both languages")
  func thinkingCopyKeysResolve() {
    #expect(
      AuraCopy.text("conversation.thinking", language: .english) == "AURA is thinking…")
    #expect(
      AuraCopy.text("conversation.thinking", language: .turkish) == "AURA düşünüyor…")
  }

  @Test("jump-to-latest copy keys resolve in both languages")
  func jumpToLatestCopyKeysResolve() {
    #expect(
      AuraCopy.text("conversation.jumpToLatest", language: .english) == "Jump to latest")
    #expect(
      AuraCopy.text("conversation.jumpToLatest", language: .turkish) == "En sona git")
  }

  // MARK: - G1-6 Orb state→layer mapping (all six behaviors)

  @Test("orb mapping: idle renders hairline ring at rest luminance")
  func idleMapping() {
    let layers = AuraOrbStateMapping.resolve(
      status: .idle, inputLevel: nil, isSpeakingResponse: false, language: .english)
    #expect(layers.ringSegments.count == 4, "hairline ring = four quadrant strokes")
    #expect(layers.coreOpacity < 1, "idle keeps minimum luminance")
    #expect(layers.fieldOpacity <= 0.12, "rest aura is faint")
    #expect(layers.accessibilityLabel == "Idle")
  }

  @Test("orb mapping: listening ring is the live level (level→arc span)")
  func listeningMapping() {
    let quiet = AuraOrbStateMapping.resolve(
      status: .listening, inputLevel: 0, isSpeakingResponse: false, language: .english)
    let loud = AuraOrbStateMapping.resolve(
      status: .listening, inputLevel: 1, isSpeakingResponse: false, language: .english)
    let nilLevel = AuraOrbStateMapping.resolve(
      status: .listening, inputLevel: nil, isSpeakingResponse: false, language: .english)

    // The level is the arc: louder spans wider, louder strokes heavier, and
    // the aura follows the level.
    let quietSpan = quiet.ringSegments[0].endAngle - quiet.ringSegments[0].startAngle
    let loudSpan = loud.ringSegments[0].endAngle - loud.ringSegments[0].startAngle
    #expect(loudSpan > quietSpan)
    #expect(loud.ringSegments[0].lineWidth > quiet.ringSegments[0].lineWidth)
    #expect(loud.fieldOpacity > quiet.fieldOpacity)
    // nil level renders the minimum arc, never a fake mid reading.
    let nilSpan = nilLevel.ringSegments[0].endAngle - nilLevel.ringSegments[0].startAngle
    #expect(nilSpan == quietSpan)
    #expect(nilLevel.accessibilityLabel == "Listening")
  }

  @Test("orb mapping: thinking renders a single orbiting arc")
  func thinkingMapping() {
    let layers = AuraOrbStateMapping.resolve(
      status: .thinking, inputLevel: nil, isSpeakingResponse: false, language: .english)
    #expect(layers.ringSegments.count == 1, "thinking = one orbiting arc")
    let arc = layers.ringSegments[0]
    #expect(arc.endAngle - arc.startAngle < 360, "an arc, not a full ring")
    #expect(arc.dash == nil)
    #expect(layers.accessibilityLabel == "Thinking")
  }

  @Test("orb mapping: speaking renders ≤3 equalizer bars from real TTS state")
  func speakingMapping() {
    let active = AuraOrbStateMapping.resolve(
      status: .speaking, inputLevel: nil, isSpeakingResponse: true, language: .english)
    #expect(active.ringSegments.count == 3, "the ≤3-bar budget")
    let inactive = AuraOrbStateMapping.resolve(
      status: .speaking, inputLevel: nil, isSpeakingResponse: false, language: .english)
    #expect(inactive.ringSegments.count == 4, "no bars → rest-pose hairline, never idle-styled core")
    #expect(inactive.coreOpacity > 0.5, "still reads as speaking")
    #expect(active.accessibilityLabel == "Speaking")
  }

  @Test("orb mapping: restricted renders amber dashed segment")
  func restrictedMapping() {
    let layers = AuraOrbStateMapping.resolve(
      status: .restricted, inputLevel: nil, isSpeakingResponse: false, language: .english)
    #expect(layers.ringSegments.count == 1)
    #expect(layers.ringSegments[0].dash != nil, "dashes survive without color")
    #expect(layers.accessibilityLabel == "Restricted")
  }

  @Test("orb mapping: error renders critical segment at full opacity")
  func errorMapping() {
    let layers = AuraOrbStateMapping.resolve(
      status: .error, inputLevel: nil, isSpeakingResponse: false, language: .english)
    #expect(layers.ringSegments.count == 1)
    #expect(layers.ringSegments[0].opacity == 1)
    #expect(layers.coreOpacity == 1)
    #expect(layers.accessibilityLabel == "Error")
  }

  @Test("orb mapping: inputLevel only reaches the ring while listening")
  func levelGatedByStatus() {
    // A stray level while idle/thinking must not change those states' layers.
    let idleWithLevel = AuraOrbStateMapping.resolve(
      status: .idle, inputLevel: 0.9, isSpeakingResponse: false, language: .english)
    let idleClean = AuraOrbStateMapping.resolve(
      status: .idle, inputLevel: nil, isSpeakingResponse: false, language: .english)
    #expect(idleWithLevel == idleClean)

    let thinkingWithLevel = AuraOrbStateMapping.resolve(
      status: .thinking, inputLevel: 0.9, isSpeakingResponse: true, language: .english)
    let thinkingClean = AuraOrbStateMapping.resolve(
      status: .thinking, inputLevel: nil, isSpeakingResponse: false, language: .english)
    #expect(thinkingWithLevel == thinkingClean)
  }

  @Test("orb mapping: still readout resolves in Turkish too")
  func turkishReadouts() {
    let layers = AuraOrbStateMapping.resolve(
      status: .listening, inputLevel: 0.5, isSpeakingResponse: false, language: .turkish)
    #expect(layers.accessibilityLabel == "Dinleniyor")
    let error = AuraOrbStateMapping.resolve(
      status: .error, inputLevel: nil, isSpeakingResponse: false, language: .turkish)
    #expect(error.accessibilityLabel == "Hata")
  }

  @Test("orb mapping: orbit angle is a pure function of time at 120°/s")
  func orbitAnglePinned() {
    let epoch = AuraOrbStateMapping.orbitEpoch
    let angle = AuraOrbStateMapping.orbitAngle(at: epoch.addingTimeInterval(1))
    #expect(angle == AuraOrbStateMapping.orbitDegreesPerSecond)
    // Determinism: same input, same output.
    #expect(
      AuraOrbStateMapping.orbitAngle(at: epoch.addingTimeInterval(2.5))
        == AuraOrbStateMapping.orbitAngle(at: epoch.addingTimeInterval(2.5)))
  }
}