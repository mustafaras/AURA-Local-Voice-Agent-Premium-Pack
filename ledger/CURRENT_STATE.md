# Current State

This file is a compact, atomically replaced projection of the append-only ledger.
Projection refreshed from live repository and command evidence on 2026-08-11.

## Canonical State Notice — 2026-08-09

The authoritative current state is
`AURA_RUNTIME_COMPLETION/state/current-state.json`, with live repository
`HEAD == origin/main == 6e53e6a941756e4b34f24f5de3c9c29bdc8147bf`; its
audited product/content baseline remains
`47775180c224f87fa5a58703f793515ffcb2c35c` under ADR-045. R2 through R12 remain
`in_progress` with deferred/live/manual/security/release/beta gates recorded in
`AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`. FINAL/CLOSEOUT is active by
explicit user request for a blocked acceptance audit and maintainer handoff;
it cannot claim release-candidate verification or release. The R11 local
`development_unverified` artifact, manifest, SBOM, checksum, and fail-closed
validator remain the only release evidence; CI artifact retention is configured
but unobserved. This legacy projection is retained for historical compatibility;
the machine-readable state remains authoritative.

## Latest Verification Snapshot — 2026-08-10

## Repository Hygiene Refresh — 2026-08-11

The canonical hygiene state remains `H-010` / `blocked` at
`HEAD == origin/main == 63f1e67bf1457e53d07cf282d8b4af1bcc33cba5`. User-controlled
Xcode 27.0 beta 5 provisioning succeeded; `xcodebuild`, SourceKit, strict
formatter/build, and the default 21-bundle/794-test/70.18% wrapper gate pass.
The wrapper now discovers the full-Xcode `MacOSX.platform` Testing runtime.
Full SwiftLint executes with SourceKit but exits 2 with 1,330 serious findings
across 628 files, so H-010 remains blocked on bounded source/test lint
remediation. No H-011 exists and no product/release completion claim follows.
Evidence: `EV-REPO-HYGIENE-TOOLCHAIN-XCODE-20260811-01` and
`EV-REPO-HYGIENE-H-010-REVALIDATION-20260811-01`.

### Repository hygiene program overlay

The repository-hygiene audit is now encoded as the canonical plan
`docs/operations/REPO_HYGIENE_PROGRAM.md` and the synchronized H-000–H-010
control plane under `AURA_RUNTIME_COMPLETION/repo-hygiene/`. H-000 through
H-009 are complete for chain-order purposes; H-010 is active and `blocked`
after the final gate preserved explicit evidence-backed limitations. H-007's explicit host-boundary scope
measured 70.02% against the unchanged 70% line-coverage ratchet; raw all-source
coverage remains 65.15%. The verified H-008 feature commit was pushed and
merged to `main` at `47775180c224f87fa5a58703f793515ffcb2c35c`; the synchronized
state projection follows that delivery. The H-008 duplicate-backup quarantine
was recoverable and SHA-validated; no original Git object recovery mutation has
been performed. The H-005 delivery is now
merged and pushed at `3b1aa85f8c55e17b49c43daea008f98fd6515f15`, followed by
the synchronized state projection commit at live `HEAD == origin/main ==
6c4cc993f86c029ce754c5e540399beb781899bb`. The worktree is clean after the
H-008 duplicate-backup quarantine; the six byte-identical mode-600 copies are
preserved outside the repository at
`/Users/m_ras/Desktop/AURA-H008-QUARANTINE-20260810`. H-006 removed production
`try!`, `as!`, and direct `print()` matches, bounded the AX bridges, and made reviewed diagnostics
metadata-only/private;
`Runtime/chatterbox/.gitignore` remains the intended H-003 control-plane
configuration change. The original checkout's `git fsck` remains non-zero
(exit 8; 199 bad SHA-1 file entries, 8,909 dangling objects, and two invalid
`refs/.DS_Store` records), while the fresh remote clone's strict fsck exits 0
and its main reachable closure matches. H-004 established the active
macOS 27+/arm64/Swift 6.4/SDK 27 baseline, reconciled 21 Swift test targets,
removes stale active prompt-path guidance, and uses discovered/fail-closed
Swift Testing paths. H-005 strict production build and the canonical
21-bundle/794-test wrapper pass; configured recursive formatter lint now exits
0 after bounded remediation of 1,019 findings across 116 Swift files.
SwiftLint 0.65.0 is provisioned, but full SourceKit-backed lint remains
explicitly blocked by the active CLT-only developer directory; its no-SourceKit
fallback is partial and not a pass. H-005 was delivered at
`3b1aa85f8c55e17b49c43daea008f98fd6515f15`; H-006 is complete for chain
order and H-007 is complete for chain order; H-008 and H-009 are complete for
chain-order purposes; H-010's final gate ran the available checks and preserved
formal blockers. H-008's fail-closed current-tree
secret/dependency/workflow validator passes, and the full local matrix is
21/21 bundles and 794/794 tests. Evidence:
`EV-REPO-HYGIENE-H-005-20260810-02` and
`EV-REPO-HYGIENE-H-005-CLOSEOUT-20260810-02`,
`EV-REPO-HYGIENE-H-006-20260810-01`, and
`EV-REPO-HYGIENE-H-006-CLOSEOUT-20260810-01`, and
`EV-REPO-HYGIENE-H-007-20260810-01`, and
`EV-REPO-HYGIENE-H-008-20260810-01`, and
`EV-REPO-HYGIENE-H-009-20260810-01`, and
`EV-REPO-HYGIENE-H-010-20260810-01`.

Separate remediation evidence `EV-REPO-HYGIENE-REMEDIATION-20260810-01` records
the recoverable backup, independently verified clean clone, formatter/source
fix, provisioned scanners, exact false-positive policies, pre-commit/local
validation, and the remaining original-Git, full-Xcode/SourceKit, dependency,
and hosted-CI blockers. Follow-up evidence
`EV-REPO-HYGIENE-DEPENDENCY-REMEDIATION-20260811-01` closes the current
lock-graph dependency advisory risk: OSV and Grype are zero under the explicit
generated-environment boundary, and runtime/audio/helper checks pass. H-010
remains blocked only by full-Xcode/SourceKit and hosted-CI evidence; the
original `.git` was adopted from the fsck-clean candidate and its damaged
pre-adoption copy is preserved for rollback. This remediation does not create
or authorize H-011.

- R11 local artifact/manifest evidence `EV-R11-20260809-ARTIFACT-MANIFEST-01`
  remains valid: the reproducible ZIP is `development_unverified`, its recorded
  SHA-256 is
  `31073b4051d1ef1c8ca5761278370e353c030fc7d6e7d6add032c4a4ed3c5e22`, and
  focused/governance tests are green.
- The CI workflow statically parses and invokes the same fail-closed builder,
  then retains only the ZIP/manifest for 14 days. This configuration is not
  observed CI evidence until a real post-change run is inspected.
- No commit, push, merge, signing, notarization, installation, release, or
  deployment was performed for the R11 worktree.
- R12 transition and the blocked readiness contract are recorded as edit-only
  beta-readiness work. No cohort, telemetry, SLO, incident, independent
  sign-off, or release-candidate evidence exists; ADR-047 is absent.
- FINAL/CLOSEOUT reconciliation is recorded under
  `EV-FINAL-20260809-CLOSEOUT-BLOCKED-01` and
  `docs/operations/FINAL_OPERATIONAL_HANDOFF.md`; no release, beta enrollment,
  telemetry activation, signing, installation, commit, push, merge, or deploy
  was performed.

The older status sections below are historical and must not override the
canonical machine state.

## Historical Verification Snapshot — 2026-08-08

- R2/R3/R4 runtime and governance changes are present at live `daf062a`; the worktree is intentionally dirty; R5, R6, R7, R8, and R9 first-pass changes remain local and uncommitted. R5 full regression passed 21/21 bundles, 747/747 tests; R6 full regression passed 21/21 bundles, 751/751 tests, both with 0 failed bundles. R8 focused memory/context validation passed 30/30 and 33/33; full R8 regression passed 21/21 bundles and 782/782 tests with zero failed bundles, and governance passed. R9 `swift build --target AURA` passed; the direct R9 UI-state run passed 3/3.
- R2 bilingual NLU/dialogue implemented and system-tested but not formally closed (live hardware evidence pending).
- R3 capability registry/typed planner architectural core implemented and tested (ADR-038 accepted) but not complete.
- R4 computer-use productization deterministic core and registry wiring implemented and tested (ADR-039 accepted) but not complete (live beta-app evidence pending).
- R5 browser/mail/calendar/contacts adapters, R6 coding-agent routes, and R7 voice/resource governance remain open; **ADR-040 is Accepted**, while ADR-041, ADR-042, and ADR-043 remain Proposed. R8 memory/context is locally bounded and explainable, but production reference wiring, user-present controls, remote transport evidence, and live acceptance remain open.
- `swift-format`/full Xcode and release gates remain unavailable or open.

- Code revision `20571de` contains the verified sequential Swift test runner and serialized system-TTS latency suite.
- Full repository validation passes: 20 test bundles, 665 tests, 0 failed bundles. The release `AURA.app` bundle and PluginHost/AutomationHelper/ShellHelper payloads also build successfully under `/tmp/aura-app-after`.
- An unsigned AURA executable launched from a workspace-local bundle with an isolated `HOME` and stayed alive for the 12-second watchdog window without crash output. This is a bounded startup smoke only; it does not prove signing, TCC, GUI, microphone, Screen Recording, real wake-word, or release behavior.
- `git diff --check` and shell syntax checks pass. `swift-format` is unavailable on this host.
- R6's policy/bridge and typed-route slices remain source/build verified, with live extension/backend acceptance open. R8 focused evidence is recorded under `EV-R8-20260808-MEMORY-POLICY-01` and `EV-R8-20260808-CONTEXT-PRODUCT-02`; these are subsystem/integration evidence, not live product acceptance.
- Next safe action: perform user-present R9 VoiceOver/keyboard/localization/onboarding/manual acceptance and complete or explicitly scope remaining product-control gaps; keep R2-R8 open and stop before R10 until R9 is evidenced.

- Phase: Phase 25 adversarial safety harness and red-team evaluation suite is
  implemented, verified, and closed. Phase 24 layered configuration is
  committed and pushed at `HEAD == origin/main == ba9842f`.
  The 20-phase implementation roadmap (`prompts/implementation/00_00` through
  `20_20_RELEASE`) is complete; remaining work is release gates and optional
  master-prompt phases 26–30.
  ADR-034 (Accessibility/CLI privilege separation) is **In Progress**.
  Milestone 1 is complete: `AuraAutomationHelper` and `AuraShellHelper` sandboxed
  executables, shared `AuraCore` IPC types, helper entitlements, and updated
  build/sign/verify scripts all build and self-attest. Milestone 2 (protocol
  boundary, in-process fallback, and `AuraKernel` selection) is pending.
- Chatterbox V3 model download: completed 2026-07-30. The pinned snapshot from
  `ResembleAI/chatterbox` revision `5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18`
  (multilingual-v3) is present under
  `~/Library/Application Support/AURA/chatterbox-model` (~3.5 GB, 6 files).
  `AURA_MODEL_MANIFEST.json` was generated and all SHA-256 hashes were verified
  against the manifest.
- Live neural-synthesis diagnostic benchmark: completed 2026-07-30 on CPU.
  First offline Turkish WAV synthesized at
  `~/Library/Application Support/AURA/chatterbox-test-output/98578148-80db-4965-8402-7d0bf52762a1.wav`
  (24 kHz mono IEEE Float, 266 KB, 68,160 frames, ~8,268 ms synthesis time).
  MPS sampling stalled at ~10% on this host session; CPU fallback succeeded.
- Phase 25 deliverables:
  - New `Tests/AuraAdversarialTests` Swift Testing target with `Fakes.swift` and
    nine eval files: 61/61 tests pass.
  - `scripts/aura-test.sh` default loop builds and runs the new bundle.
  - `AURA_ENABLE_COVERAGE=1 AURA_COVERAGE_MIN=70 ./scripts/aura-test.sh` reports
    `line coverage 70.24% meets 70%` (re-run on 2026-07-30 after TTS latency
    stabilized).
  - New ops docs: `docs/operations/ADVERSARIAL_INCIDENT_RESPONSE.md` and
    `docs/operations/SECURITY_REVIEW_SCHEDULE.md`, referenced from ADR-033 and
    `Sources/AuraCore/ResidualRiskRegistry.swift`.
  - `PromptInjectionClassifier` extended with a deterministic non-English
    instruction-override rule.
- Git state: Phase 24 and Phase 25 changes remain committed and pushed to
  `origin/main == ba9842f`. ADR-034 milestone-1 changes are local-only. The
  `.vscode/launch.json` change is now part of ADR-034 because it adds launch
  configurations for the new helper executable targets.
- Next safe action: Continue ADR-034 milestone 2 (protocol boundary and
  `AuraKernel` selection). Pending release gates otherwise remain consented
  reference audio / human listening (deferred by user choice), Screen Recording
  consent, Developer ID signing/notarization, public plugin PKI, real acoustic
  wake-word model, and completing main-process Accessibility/CLI privilege
  separation. Optionally begin master-prompt Phase 26 after explicit user
  authorization.

  The earlier voice implementation
  `4ffa2139f38ba343707d3c8b393be11259851265` and evidence commit
  `b635b59fd64359d9d3f9a918890bb239161b76f1` were pushed on
  `feature/native-voice-chatterbox-v3`, then merged by explicit no-fast-forward
  commit `e2d7396319c0431b17164284d83ca76624a04e31`. Local `main`,
  `origin/main`, and the transport ref were equal at that merge commit. The
  pre-existing `.vscode/launch.json` change remains outside scope and is not
  part of Phase 24.
- Product lifecycle:
  - Native SwiftUI dashboard window, retained menu-bar control, and Settings
    scene.
  - Settings includes user-controlled local recommendation opt-in, effective
    configuration inspection, changed-value/source display, and audit count.
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
  - `AuraConfig.ConfigurationEngine` is constructed before policy/runtime
    services and persists one versioned state envelope through `AuraStore`.
  - Configuration resolution is secure defaults → machine policy → user →
    project → session. Project/session settings cannot weaken registered
    security bounds; session overrides expire on restart.
  - Feature flags are owner/purpose/expiry/rollback/kill-switch governed with
    stable bounded rollout. Local aggregate recommendations are opt-in,
    explainable, and never auto-applied.
- Security boundary:
  - `AuraPluginHost`, `AuraAutomationHelper`, and `AuraShellHelper` are
    separately packaged, App Sandbox entitled helpers with network denied and
    live self-attestation (`--attest-only` prints `sandbox-ok`).
  - The main app remains intentionally non-sandboxed while Accessibility and
    CLI execution remain in-process. Main-process network controls are
    policy/allowlist controls, not OS sandbox enforcement. ADR-034 milestone 1
    delivers the helper executables; milestone 2 will add the protocol boundary
    and switch `AuraKernel` to use the helper-backed path when configured.
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
  - `AuraConfigTests` passes 17/17. Tests cover atomic persistence failure,
    restart-surviving rollback, ephemeral session expiry, forward/reverse
    migration, non-weakening project/machine policy, flag expiry/kill switch,
    stable rollout, and explicit recommendation acceptance.
  - Phase 25 `AuraAdversarialTests` passes 61/61 tests, including prompt
    injection (multi-language and authority-boundary), tool spoofing, policy
    bypass/deny precedence, memory poisoning with seeded baseline, structured
    output, plugin supply-chain tampering, configuration non-weakening, and
    residual-risk registry references.
  - `AURA_ENABLE_COVERAGE=1 AURA_COVERAGE_MIN=70 ./scripts/aura-test.sh` passes
    all 19 + 1 bundles and reports `TOTAL line coverage 70.23%` with
    `PASSED: line coverage 70.23% meets 70%`.
  - ADR-034 milestone 1: `swift build --product AuraAutomationHelper --product
    AuraShellHelper` succeeds; `AURA_ENABLE_COVERAGE=0
    ./scripts/aura-test.sh /tmp/aurabuild-adr034-smoke` passes all 20 bundles;
    `./scripts/build-app-bundle.sh` packages the new helpers into
    `AURA.app/Contents/Helpers/`; `zsh -n` passes for the three modified shell
    scripts; `git diff --check` passes.
  - Phase 24 release app/helper packaging, stable local signing, and deep/strict
    verification pass under `/tmp`. Main package CDHash:
    `988b4cc89093eadb46c1df21d5f4a98029ba0989`.
  - Current-run Phase 24 line coverage is at least 80.00% per new source file;
    `ConfigurationEngine` is 80.83%.
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
  - Phase 24 closure: `AURA_ENABLE_COVERAGE=1 ./scripts/aura-test.sh
    /tmp/aurabuild-phase24-final` passed all 19 Swift Testing bundles with
    70.11% line coverage (≥70% ratchet).
- Phase 25 closure: `AURA_ENABLE_COVERAGE=1 AURA_COVERAGE_MIN=70
    ./scripts/aura-test.sh /tmp/aurabuild` passed all 20 Swift Testing bundles
    with 70.23% line coverage (≥70% ratchet).
- Manual/release gates still open:
  - The post-Phase-24 19-bundle run now passes all 19 bundles with 70.11% line
    coverage. The transient `AVSpeechSynthesizer` callback stall recovered
    without a system service restart; no test or timeout was weakened.
  - Real `CGEvent`, VoiceOver reading order, contrast, Dynamic Type, and live
    screen-content behavior still require release-hardware validation.
  - Screen Recording was reset from the old ad-hoc identity and is not yet
    granted to the stable identity. The installed app now provides a supported
    explicit request button; its secure consent and post-restart preflight
    remain required.
  - ✅ The pinned ~3.5 GB Chatterbox V3 model snapshot downloaded from the
    official Hugging Face revision `5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18`
    and `AURA_MODEL_MANIFEST.json` was generated with SHA-256 bindings.
  - ✅ Live neural-synthesis diagnostic benchmark completed on CPU (MPS stalled
    at ~10% on this host session; CPU fallback succeeded). WAV is valid
    24 kHz mono IEEE Float, 266 KB, 68,160 frames, ~8,268 ms synthesis time.
  - ⏸️ Owned/consented bounded female reference WAV and one human-listened
    Turkish turn are deferred by user choice. AURA remains fail-closed on the
    local female `tr-TR` Yelda system voice until an owned/consented reference
    is supplied.
  - Real acoustic wake-word model, Developer ID signing/notarization, public plugin vendor PKI/catalog, and real third-party payload execution remain unavailable external-material/release gates.
  - The main-process Accessibility/CLI privileges should ultimately move behind least-privilege helpers before claiming OS-enforced network confinement.
- Release status: the earlier voice repair is committed, feature-pushed,
  merged, and remotely verified. Phase 24 and Phase 25 are committed locally
  at `HEAD == bdc1ccd`; `origin/main == a116332` because the most recent push
  failed with a 403 network error. No release, deploy, notarization, public
  marketplace publication, application install/launch, or TCC mutation was
  performed. A verified Phase 24 package exists only under `/tmp`; AURA remains
  closed.
- Next safe action: Implement the `AuraAdversarialTests` target scaffold, add
  the first deterministic eval cases (prompt injection, tool spoofing, policy
  bypass, memory poisoning, structured-output abuse, capability-boundary
  violation), then run the full repository coverage gate. Do not commit, push,
  merge, or release without explicit authorization.

### H-010 current hygiene overlay — 2026-08-12

H-010 bounded `Sources/Tests` remediation was executed under explicit user
authority. Xcode/SourceKit, strict formatter, strict build, and full strict
tests pass. The exact SwiftLint policy still exits 2 with 528 serious findings;
the canonical wrapper runs all 21 bundles with zero bundle failures but exits 1
at 66.10% coverage under the unchanged 70% threshold. H-010 remains blocked,
the original six-file scope is preserved, and no H-011 or Git delivery action
occurred. Evidence: `EV-REPO-HYGIENE-H-010-SWIFTLINT-REMEDIATION-20260812-01`.
