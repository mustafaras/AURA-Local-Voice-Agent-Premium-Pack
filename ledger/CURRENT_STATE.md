# Current State

This file is a compact, atomically replaced projection of the append-only ledger.
Projection refreshed from live repository and command evidence on 2026-07-29.

- Phase: Phase 0–23 runtime/UI remediation is committed and remotely verified;
  Push-to-Talk/native-audio repair, stable local signing, natural Turkish TTS,
  explicit Screen Recording onboarding, and the local Chatterbox V3 adapter are
  implemented and under final live acceptance; Phase 24 not started.
- Git state: voice implementation
  `4ffa2139f38ba343707d3c8b393be11259851265` and evidence commit
  `b635b59fd64359d9d3f9a918890bb239161b76f1` were pushed on
  `feature/native-voice-chatterbox-v3`, then merged by explicit no-fast-forward
  commit `e2d7396319c0431b17164284d83ca76624a04e31`. Local `main`,
  `origin/main`, and the transport ref were equal at that merge commit. The
  pre-existing `.vscode/launch.json` change remains outside scope.
- Product lifecycle:
  - Native SwiftUI dashboard window, retained menu-bar control, and Settings
    scene.
  - Clean-profile `0700` Application Support bootstrap before `AuraStore`.
  - Missing Speech/microphone authorization is recoverable and never triggers a startup prompt.
  - Explicit voice onboarding, push-to-talk, status, recent tasks, runtime warnings, confirmations, settings/privacy links, and visible/global emergency stop.
  - Explicit Screen Recording onboarding uses
    `CGRequestScreenCaptureAccess`; the manual System Settings route remains a
    fallback.
  - Voice capture is deferred until explicit permissions are granted, so a
    clean TCC profile reaches onboarding without blocking in CoreAudio.
  - Push-to-Talk sessions close after speech plus configured VAD silence, with
    a hard fallback below the conversation timeout. Native final callbacks and
    consecutive STT turns remain consumable; STT errors cannot enter intent.
  - The AVFoundation tap copies callback-owned PCM before crossing actor
    isolation. Real frames are looked up by exact sequence and ingested once;
    no empty placeholder frame reaches native Speech. Concrete STT failures
    end the listening turn as visible errors instead of a later generic timeout.
  - No trained acoustic wake-word model is bundled; the UI discloses
    push-to-talk as the supported path, and production samples do not feed the
    synthetic marker detector.
- Runtime composition:
  - Core audio/STT/intent/conversation/task pipeline remains wired.
  - Implemented Screen, Computer Use, Security, Plugin, VS Code, Ollama, worktree, and multi-agent services are constructed behind existing policy, permission, trust, and configuration gates.
  - Confirmation challenges use one nonce/hash/expiry-bound UI presenter and deny on missing UI, dismissal, timeout, shutdown, or overlap.
- Security boundary:
  - `AuraPluginHost` remains a separately signed, restrictive App Sandbox helper with live self-attestation.
  - The main app is intentionally unsandboxed while Accessibility and CLI execution remain in-process. Main-process network controls are policy/allowlist controls, not OS sandbox enforcement.
  - Local packages prefer the trusted `AURA Stable Local Signing` Keychain
    identity and retain Hardened Runtime plus the existing least-privilege
    entitlements. The stable designated requirement preserves TCC identity
    across rebuilds. This is not Developer ID or notarization.
  - Accessibility and Screen Recording remain user-controlled macOS TCC
    grants, not fabricated signing entitlements.
  - The immediate fallback explicitly selects local female `tr-TR` Yelda and
    maps `1.0` to AVFoundation's normal rate rather than its absolute maximum.
  - Chatterbox Multilingual V3 runs in a separate persistent Python 3.11
    process with pinned source/model revisions, offline runtime mode, bounded
    stdin/stdout JSON, hash-manifest enforcement, private WAV containment and
    cleanup, and PerTh watermark preservation.
  - Neural speech is consent-gated: without an owned/consented bounded PCM
    female reference WAV, AURA remains on Yelda.
- Verified evidence:
  - Changed Swift files pass strict `swift format lint`; the repository diff
    passes `git diff --check`.
  - `AURA` passes a fresh warnings-as-errors build after the permission/TTS
    changes.
  - All 18 test bundles pass from a fresh final build path: 587/587 tests.
  - Post-Chatterbox LLVM line coverage is 70.12%; it meets the 70% CI ratchet,
    with 80% retained as the next target.
  - Natural-voice scoped gates pass: `AuraAudioTests` 33/33,
    `AuraCoreTests` 7/7, `AuraAgentTests` 205/205, and
    `AURAIntegrationTests` 16/16. Integration passed again after the explicit
    Screen Recording request correction.
  - Release app build, stable main/helper signing, and deep/strict validation
    pass. Two packages have the same certificate-root designated requirement.
  - Installed-package CDHash:
    `d7a5b529e63b0377682d1192504952542fc5d30a`; signature flags include
    `runtime`, and authority is `AURA Stable Local Signing`.
  - Final packaged clean-profile smoke remained alive for eight seconds until watchdog exit, created `aura.db`, and verified directory mode `0700`.
  - The latest capture-transport repair also passes `AuraAudioTests` 32/32 on
    rerun, `AuraSTTTests` 14/14, and `AURAIntegrationTests` 16/16. One initial
    unrelated wall-clock System TTS latency check exceeded its 2.0 s budget at
    2.754 s and passed on immediate isolated rerun.
  - The post-Chatterbox full repository gate passes all 18 Swift Testing
    bundles, 587/587 tests. `AuraAudioTests` passes 33/33 including fallback,
    warm-up, prompt-bound, path-escape, cleanup, and stop cases.
  - Four Python integrity/reference tests pass; Python sources pass
    `py_compile`; the live helper rejects the incomplete snapshot before model
    import with a bounded fatal JSON envelope.
  - The pinned Python 3.11.15 environment is installed externally and imports
    Chatterbox 0.1.7 from official source commit `5de7a54`, Torch/Torchaudio
    2.6.0, and available MPS support.
  - A release app containing the exact audited helper source passes stable
    signing and strict/deep verification. Package CDHash:
    `d7a5b529e63b0377682d1192504952542fc5d30a`.
  - Microphone and Speech Recognition are granted to the stable identity and
    persisted across a subsequent rebuild/reinstall. Accessibility is enabled
    for AURA in System Settings.
  - Clean-permission launch reaches restricted onboarding without touching
    CoreAudio. Deterministic tests prove one-shot finalization, hard timeout,
    consecutive turns, and error isolation.
  - Main/helper plists pass `plutil -lint`.
- Manual/release gates still open:
  - Real `CGEvent`, VoiceOver reading order, contrast, Dynamic Type, and live
    screen-content behavior still require release-hardware validation.
  - Screen Recording was reset from the old ad-hoc identity and is not yet
    granted to the stable identity. The installed app now provides a supported
    explicit request button; its secure consent and post-restart preflight
    remain required.
  - The pinned 3.21 GB Chatterbox V3 model snapshot is still downloading from
    the official Hugging Face revision. No integrity manifest or real neural
    synthesis claim exists until that download and hashing finish.
  - The owned/consented female reference WAV is absent. One human-spoken
    Push-to-Talk to stable transcript to spoken response turn, including
    perceptual voice/persona judgment, remains deferred until the evening.
  - Real acoustic wake-word model, Developer ID signing/notarization, public plugin vendor PKI/catalog, and real third-party payload execution remain unavailable external-material/release gates.
  - The main-process Accessibility/CLI privileges should ultimately move behind least-privilege helpers before claiming OS-enforced network confinement.
- Release status: the repair is committed, feature-pushed, merged, and remotely
  verified. No release, deploy, notarization, or public marketplace publication
  was performed. The stable-signed local package was replaced with a verified
  rollback backup under `/tmp`; AURA was left closed.
- Next safe action: Let the pinned model download finish, verify its generated
  SHA-256 manifest, and run one non-accepted diagnostic synthesis/benchmark.
  Then add an owned/consented female PCM WAV and complete one human-listened
  Turkish turn. Screen Recording consent remains a separate secure UI gate.
