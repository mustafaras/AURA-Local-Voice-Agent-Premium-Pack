---
id: PA-0
sequence: 0
track: PA
depends_on: none
next_prompt: PA-1
state: pending
design_docs: 01-owner-trust-posture, 07-cross-cutting-constraints
adr: ADR-064
---

# PA-0 — Owner Trust Posture (no confirmation loop)

## Mission

Make the policy engine answer `.allow` — with no confirmation challenge — for the owner actor on every registered capability, through seeded grants and one ADR, while leaving the engine, the audit trail, the emergency stop, and every structural guard exactly as they are.

## Read before acting (anti-amnesia context)

- `ledger/CURRENT_PHASE.md`, tail of `ledger/PHASE_LEDGER.md`, `00-working-protocol.md` §3–§6
- `01-owner-trust-posture.md` (all sections), `07-cross-cutting-constraints.md` §1
- Repo: `ledger/CURRENT_STATE.md` (top entry), `ledger/PROJECT_LEDGER.md` (tail), `docs/decisions/ADR-055-owner-directed-local-enablement.md`, `docs/decisions/ADR_TEMPLATE.md`
- Code: `Sources/AuraPolicy/DefaultPolicyGrants.swift`, `Sources/AuraPolicy/PolicyEngine_Evaluation.swift:30-70`, `Sources/AuraCore/PolicyTypes_PolicyConfiguration.swift:19-40`, `Sources/AURA/AuraKernel_Grants.swift:23-37`, `Sources/AURA/UIConfirmationPresenter.swift`, `Sources/AuraIntent/InitialCapabilitySet_CapabilityDefinitions.swift:11-105`
- Tests that pin the current posture: `Tests/AuraPolicyTests/PolicyEngineTests*.swift`, `Tests/AURAIntegrationTests/SP003LiveBilingualDialogueScenarios.swift`, `SP006LiveCapabilityScenarios.swift`, `Tests/AuraAgentTests/*TaskRunnerTests*.swift`, `OllamaAdapterTests.swift`
- Owner decisions D-1 and D-2 must exist as `DECISION:` lines in the ledger before G0-1.

## Hard boundaries

- **Allowed files:** `Sources/AuraPolicy/DefaultPolicyGrants.swift`, `Sources/AuraPolicy/OwnerTrustPosture.swift` (new), the pinned tests listed above (assertion updates only, each with an `// ADR-064` comment), one new coverage test file, `docs/decisions/ADR-064-owner-trust-posture.md`, `ledger/PROJECT_LEDGER.md`, `ledger/CURRENT_STATE.md`, this plan's ledger. **Nothing else.**
- Forbidden: editing `PolicyEngine_Evaluation.swift`, `PolicyConfiguration` tiers, `UIConfirmationPresenter` production wiring, `EmergencyShortcutMonitor`, any computer-use guard, any manifest `confirmationRule` string.
- Test fixtures that build their own `.always` grants to test challenge mechanics are **not** modified.
- No commit/push without an explicit go-ahead in the turn.

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G0-1 | `[policy]` ADR-064 written per template: owner instruction verbatim, decision, non-transferable boundary, falsifiers, evidence class; D-1/D-2 `DECISION:` lines present | `ls docs/decisions/ADR-064-*.md`; `grep -c '^DECISION: D-[12]' ledger/PHASE_LEDGER.md` = 2 |
| G0-2 | `[policy]` `OwnerTrustPosture.isEnabled` introduced; the seven challenging grants derive `.none` from it; `OwnerTrustPostureTests` prove the switch is the only difference | `unit`: tests green; `grep -c 'confirmationRequirement: .always' DefaultPolicyGrants.swift` = 0 |
| G0-3 | `[policy]` Grant coverage: every capability named by `InitialCapabilitySet.manifests()` evaluates `.allow` with no challenge for `actor: .user`; any gap fixed with a seeded `.none` grant of the narrowest honest pattern | `unit`: `OwnerGrantCoverageTests` green; ledger lists each gap the test found |
| G0-4 | Pinned-test updates are deliberate and cited; challenge-mechanics fixtures untouched | `git diff --stat Tests/` reviewed; every changed assertion has an `ADR-064` comment (`grep -rn 'ADR-064' Tests/ \| wc -l` ≥ number of changed assertions) |
| G0-5 | Live: shell turn, coding-agent turn, app-terminate turn each complete with no confirmation card; audit shows `allow` with the seed grant ID; owner attestation recorded | `live-local` driver transcript + no card element; `owner-attested` line |
| G0-6 | Full verification + governance: suite ×2–3 green (22/22, 0 failed), ADR accepted, `PROJECT_LEDGER` append, `CURRENT_STATE` atomic rewrite | outputs captured under `evidence/PA-0/` |
| G0-7 | Machine coherence: validator OK, all gates `passed`, `phase_status: awaiting-approval` | `bash validate-continuity.sh` exit 0 |

## Per-gate procedure

- **G0-1:** Draft ADR-064 from `01-owner-trust-posture.md` §3.4. Quote the owner's 2026-09-15 instruction verbatim. Cite ADR-055 as precedent. State explicitly what is *not* changed (§3.3 of the design doc).
- **G0-2:** Add `OwnerTrustPosture.swift`. Replace the seven literal requirements with the derived constants. Run `AuraPolicyTests` alone first, then fix pinned assertions.
- **G0-3:** Write the coverage test; iterate until green. Every new grant added gets a comment naming the gap and ADR-064. Re-run `AuraPolicyTests` + `AuraIntentTests`.
- **G0-4:** `git diff Tests/` line by line; confirm only assertions about *production seed* requirements changed.
- **G0-5:** Build bundle to a fresh path under `~/Library/Developer/AURA/pa0-<date>`, stable-sign, `verify-signature.sh`, `open -a`. Run the three turns through the driver; capture transcript; capture the absence of the confirmation card (add `AuraAccessibilityID.confirmationCard` if missing — this is an *addition* in `AuraAccessibilityIdentifiers.swift` and is the one exception to the allowed-files list, recorded in the ledger).
- **G0-6/G0-7:** Standard closing sequence (§2 of `08-rollout.md`).

## Evidence template (ledger entry)

```text
## SEQ-00NN — <ISO> — PA-0 — G0-k PASSED
- evidence: <file:line | command output lines | evidence/PA-0/<file>>
- verified: <exact command>
- adr: ADR-064   ← required for [policy] gates (A7)
```

## Risks / reverting

Reverting means restoring the allowed files from git and removing the two new files; the store's seeded grants reconcile back on next launch (`reconcileSeededGrants`). If G0-3 finds a gap whose honest pattern is unclear, record it `blocked` with the capability name and ask the owner — do not seed `.any` for filesystem-class capabilities.

## Session script

Start: protocol §5 steps 1–7. Then G0-1 → G0-7 in order, one gate per checkpoint. End: `phase_status: awaiting-approval` and the question *"Faz PA-0 tamamlandı; geçiş için onayınız?"*

## Cognitive completion gate

Before declaring the phase done, answer in the ledger: (1) Which capability would still show a confirmation card, and why? (expected: none for the owner actor) (2) Which structural guard did I verify is untouched, by diff? (3) Could another Mac inherit this posture by copying the build, and where is that forbidden in writing?
