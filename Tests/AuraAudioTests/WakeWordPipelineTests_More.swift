import AuraAudio
import AuraCore
import Foundation
import Testing

extension WakeWordPipelineTests {
  @Test func privacyModeRequiresShortcut() async {
    let fixture = await makeWakePipelineFixture(
      debounceSeconds: 0.0, monotonicClock: { 0.0 }, privacyShortcut: "⇧⌘L")
    await fixture.pipeline.start()
    #expect(await fixture.pipeline.currentState() == .listening)
    await fixture.pipeline.setPrivacyMode(true, triggeredByKeyboardShortcut: false)
    #expect(await fixture.pipeline.currentState() == .privacyArmed)

    let markerFrames = SyntheticAudio.toneBurst(
      frequency: 1000,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 15
    )
    await feedWakeFrames(markerFrames, fixture: fixture)

    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(await fixture.pipeline.currentMetrics().acceptedActivations == 0)

    await fixture.pipeline.privacyShortcutPressed()
    #expect(await fixture.pipeline.currentState() == .listening)

    await fixture.pipeline.stop()
  }

  @Test func speakerVerifierEnrollsAndRecognizesMarkerVoice() async {
    let verifier = MarkerSpeakerVerifier(
      markerFrequency: 1500.0,
      markerWindowHz: 50.0,
      matchThreshold: 0.70
    )

    let enrollmentFrames = SyntheticAudio.toneBurst(
      frequency: 1500,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 10
    )
    await verifier.enroll(profileID: "owner", samples: enrollmentFrames)

    let matchFrame = SyntheticAudio.toneBurst(
      frequency: 1500,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 1
    )[0]
    let matchHint = await verifier.verify(matchFrame)
    #expect(matchHint.profileID == "owner")
    #expect(matchHint.score >= 0.70)

    let strangerFrame = SyntheticAudio.toneBurst(
      frequency: 800,
      amplitude: 0.6,
      frameLength: 512,
      burstFrames: 1
    )[0]
    let strangerHint = await verifier.verify(strangerFrame)
    #expect(strangerHint.profileID == nil)
  }
}
