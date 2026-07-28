# AURA Session Starter — Phase 24: Self-Tuning Configuration and Feature-Flag Governance

> Conversation date: 28 July 2026  
> Read `AGENTS.md`, `ledger/CURRENT_STATE.md`, and the newest
> `ledger/PROJECT_LEDGER.md` entry before changing files.

## Repository

- Path: `/Users/m_ras/Desktop/AURA-Local-Voice-Agent-Premium-Pack`
- Remote: `https://github.com/mustafaras/AURA-Local-Voice-Agent-Premium-Pack`
- Platform: macOS 26+ on Apple Silicon; Swift 6.4; CommandLineTools
- Test command: `./scripts/aura-test.sh /tmp/<unique-build-path> [bundle-filter]`
- Do not use plain `swift test` in this environment.

## Verified handoff

- Phase 23 implementation is complete in the working tree and its authorized
  evidence-backed commit/push sequence is the immediate safe action.
- Verified base before those commits:
  `HEAD == origin/main == 8115eba0d1944e4d83ea8bccd7d5719b6deafe36`.
- Phase 23 evidence:
  - `AuraPluginsTests` 37/37 pass.
  - Default full suite 356/356 pass; 393 combined targeted/full tests.
  - `AuraPluginHost` and `AURA` warnings-as-errors builds pass.
  - Final nested-helper app packaging, ad-hoc signing, strict signature and
    entitlement verification, and live sandbox self-attestation pass.
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

1. Finish and remotely verify the Phase 23 commits; require a clean tree.
2. Re-read the live Phase 24 specification at
   `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md`.
3. Inspect configuration schemas, `AuraStore`, policy risk controls, migrations,
   tests, ADR index, and threat-model entry 12.
4. Append a Phase 24 start entry with objective, assumptions, risks, acceptance
   criteria, and architectural conflict check before editing source.

## Known open risks

- Developer ID/notarized third-party plugin execution is not yet release-tested.
- No public vendor PKI, remote marketplace catalog, or marketplace UI exists.
- `AuraKernel` does not yet construct the plugin runtime.
- Real acoustic wake-word, neural STT, and Chatterbox inference remain
  unintegrated.
