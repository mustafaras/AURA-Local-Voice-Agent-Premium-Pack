# AURA Session Starter — Verified Voice Remediation Handoff Before Phase 24

> Conversation date: 29 July 2026
> Read `AGENTS.md`, `ledger/CURRENT_STATE.md`, and the newest
> `ledger/PROJECT_LEDGER.md` entry before changing files.

## Repository

- Path: `/Users/m_ras/Desktop/AURA-Local-Voice-Agent-Premium-Pack`
- Remote: `https://github.com/mustafaras/AURA-Local-Voice-Agent-Premium-Pack`
- Platform: macOS 27+ on Apple Silicon; Swift 6.4; CommandLineTools
- Test command: `./scripts/aura-test.sh /tmp/<unique-build-path> [bundle-filter]`
- Do not use plain `swift test` in this environment.

## Verified handoff

- Phase 23 implementation and state commits are remotely verified. The
  subsequent runtime/UI, TCC/signing, Push-to-Talk, and Chatterbox V3
  remediation is implemented, locally verified, and committed as
  `4ffa2139f38ba343707d3c8b393be11259851265` on
  `feature/native-voice-chatterbox-v3`; its user-authorized push/merge is the
  current closing operation.
- Verified closing-evidence commit:
  `d9896539f1b8c6d94f077fe8948820f4a019b5e8` matched local `HEAD`,
  `origin/main`, and `git ls-remote` after its fast-forward push.
- Phase 23 implementation commit:
  `8afdbf2b56b8003148508b0bbd8ae49ca389fefa`.
- Current remediation evidence:
  - All 18 bundles pass, 587/587 tests; LLVM line coverage is 70.12% against
    the enforced 70% CI ratchet.
  - `AURA` warnings-as-errors build and changed-file Swift formatting pass.
  - SwiftUI dashboard/menu-bar/Settings UI, explicit permission onboarding,
    push-to-talk, confirmations, runtime/task status, and emergency stop are
    implemented.
  - A clean-profile packaged app remains alive without prior Speech permission,
    creates `aura.db` under a `0700` directory, and passes Hardened Runtime
    signing/helper sandbox verification.
  - The stable local signing identity preserves the app's designated
    requirement across rebuilds. Microphone and Speech Recognition grants
    persist; Accessibility is enabled; Screen Recording still requires the
    user's secure macOS consent.
  - Push to Talk now closes after speech followed by VAD silence or a bounded
    fallback, preserves native final callbacks, supports consecutive turns,
    copies callback-owned PCM before async delivery, forwards each exact real
    frame once, and never routes recognition errors as user intent. A live
    human-voice response check is pending.
  - Female Turkish Yelda is the immediate local fallback. The process-isolated
    Chatterbox Multilingual V3 adapter, pinned Python 3.11.15 environment,
    offline runtime mode, integrity manifest enforcement, private WAV
    containment, and consent-bound reference-audio gate are implemented.
    The official 3.21 GB snapshot is still downloading; no neural benchmark or
    accepted female production voice is claimed yet.
  - Final locally packaged CDHash:
    `d7a5b529e63b0377682d1192504952542fc5d30a`.
- No release, deployment, notarization, or public marketplace publication was
  performed.

## Phase 23 boundaries to preserve

- Plugin code never loads in the AURA process.
- Every authority-bearing manifest field is signed; payload bytes are
  SHA-256-bound and rechecked before activation/execution.
- Plugin grants are scoped to the plugin actor, time-bounded, revocable, and
  never broaden empty permissions to `.any`.
- Only enabled plugins can cross the helper boundary.
- Quarantine revokes grants; uninstall removes runtime artifacts while
  append-only audit history remains.
- Marketplace sources and vendor keys are explicitly user-controlled and local.
- The v1 helper remains network-denied at the OS layer.

## Phase 24 mission

Implement layered, self-tuning configuration with typed schemas, migration
history, feature-flag governance, A/B-safe rollout, and local,
privacy-preserving recommendations.

### Required deliverables

- Configuration precedence: secure defaults → machine policy → user settings →
  project settings → session overrides, with validation and rollback.
- Feature flags with owner, purpose, expiry, default, overrides, kill switch,
  and rollback plan.
- Opt-in, explainable recommendations from local latency, error, energy, and
  correction metrics; no raw telemetry leaves the device.
- Versioned configuration migrators reversible within a compatibility window.
- User-inspectable effective configuration, default diff, audit, and override
  revocation.

### Acceptance gate

- Project configuration cannot weaken higher-risk capabilities.
- Flags expire or require explicit renewal.
- Recommendations are explainable and opt-in.
- Rollback completes within seconds and survives restart.
- Every configuration change is logged and user-inspectable.

## First safe action

1. Preserve the pre-existing `.vscode/launch.json` change.
2. Complete the user-authorized feature-branch push/merge and verify
   local, tracking, and transport refs agree.
3. Start Phase 24 only after that verified state, then follow the normal ledger
   start sequence.

## Known open risks

- Developer ID/notarized third-party plugin execution is not yet release-tested.
- No public vendor PKI or remote marketplace catalog exists.
- Main-process network confinement is policy-based until Accessibility and CLI
  execution move behind least-privilege helpers.
- Real acoustic wake-word and neural STT remain unintegrated. Chatterbox V3 is
  integrated but cannot pass its live inference gate until the pinned snapshot
  download, hash manifest, diagnostic benchmark, consented female reference,
  and human listening test finish.
