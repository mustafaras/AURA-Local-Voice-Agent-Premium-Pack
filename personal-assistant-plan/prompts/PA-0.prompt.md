---
id: PA-0
sequence: 0
track: PA
depends_on: none
next_prompt: PA-1
state: pending
design_docs: 01-owner-trust-posture (incl. §3.3a, D-2 as resolved 2026-09-16), 07-cross-cutting-constraints
adr: ADR-064
---

# PA-0 — Owner Trust Posture (no confirmation loop)

## Mission

Make the policy engine answer `.allow` — with no confirmation challenge — for the owner actor on every registered capability, through seeded grants and one ADR; and, per D-2 as resolved on 2026-09-16, lift the computer-use structural guards (mandatory-confirmation intents; secure-field refusal and sensitive-application exclusion; unexpected-modal, no-progress, and per-plan step halts) for the owner posture through one derived `ComputerUseGuardPosture` — while leaving the engine, the audit trail, the emergency stop, identity-change detection, the iteration ceiling, and the rate limit exactly as they are.

## Read before acting (anti-amnesia context)

- `ledger/CURRENT_PHASE.md`, tail of `ledger/PHASE_LEDGER.md`, `00-working-protocol.md` §3–§6
- `01-owner-trust-posture.md` (all sections), `07-cross-cutting-constraints.md` §1
- Repo: `ledger/CURRENT_STATE.md` (top entry), `ledger/PROJECT_LEDGER.md` (tail), `docs/decisions/ADR-055-owner-directed-local-enablement.md`, `docs/decisions/ADR_TEMPLATE.md`
- Code (guards, D-2): `Sources/AuraComputerUse/ComputerUseControlLoop.swift`, `ComputerUseControlLoop_Run.swift:88-127,143-153,195-213,304-319,337-382`, `UIActionExecuting.swift:75-140`, `Sources/AuraScreen/ScreenContextEngine.swift:55-77,112-137,249-259`, `Sources/AuraCore/ComputerUseTypes.swift:59-71`, `Configuration_ComputerUseConfiguration.swift:1-9`, `Sources/AURA/AuraKernel_Construction.swift:298-325`; guard tests: `Tests/AuraComputerUseTests/ComputerUseControlLoopTests*.swift`, `R4AdversarialSafetyTests.swift`, `R4DetectorFailClosedTests.swift`, `UIActionExecutingTests.swift`, `Tests/AuraScreenTests/ScreenContextEngineTests*.swift`
- Code: `Sources/AuraPolicy/DefaultPolicyGrants.swift`, `Sources/AuraPolicy/PolicyEngine_Evaluation.swift:30-70`, `Sources/AuraCore/PolicyTypes_PolicyConfiguration.swift:19-40`, `Sources/AURA/AuraKernel_Grants.swift:23-37`, `Sources/AURA/UIConfirmationPresenter.swift`, `Sources/AuraIntent/InitialCapabilitySet_CapabilityDefinitions.swift:11-105`
- Tests that pin the current posture: `Tests/AuraPolicyTests/PolicyEngineTests*.swift`, `Tests/AURAIntegrationTests/SP003LiveBilingualDialogueScenarios.swift`, `SP006LiveCapabilityScenarios.swift`, `Tests/AuraAgentTests/*TaskRunnerTests*.swift`, `OllamaAdapterTests.swift`
- Owner decisions D-1 and D-2 must exist as `DECISION:` lines in the ledger before G0-1.

## Hard boundaries

- **Allowed files:** `Sources/AuraPolicy/DefaultPolicyGrants.swift`, `Sources/AuraPolicy/OwnerTrustPosture.swift` (new), `Sources/AuraComputerUse/ComputerUseGuardPosture.swift` (new), `Sources/AuraComputerUse/ComputerUseControlLoop.swift`, `Sources/AuraComputerUse/ComputerUseControlLoop_Run.swift`, `Sources/AuraComputerUse/UIActionExecuting.swift`, `Sources/AuraScreen/ScreenContextEngine.swift` (posture parameter and the guarded branches only), comment-only corrections in `Sources/AuraCore/ComputerUseTypes.swift` and `Sources/AuraCore/Configuration_ComputerUseConfiguration.swift`, the pinned tests listed above (assertion updates only, each with an `// ADR-064` comment; guard-mechanics fixtures may gain only an explicit `guardPosture: .structural` / `sensitiveApplicationExclusionEnabled: true` argument), three new test files (`OwnerTrustPostureTests`, `OwnerGrantCoverageTests`, `ComputerUseGuardPostureTests`), `docs/decisions/ADR-064-owner-trust-posture.md`, `ledger/PROJECT_LEDGER.md`, `ledger/CURRENT_STATE.md`, this plan's ledger. **Nothing else.**
- Forbidden: editing `PolicyEngine_Evaluation.swift`, `PolicyConfiguration` tiers, `UIConfirmationPresenter` production wiring, `EmergencyStopController`, `EmergencyShortcutMonitor`, any `emergencyStop.isActive` check, identity-change detection, `maxIterations`, the rate limit, the redaction pipeline, `AuraKernel_Construction.swift` (the kernel inherits the defaults), any manifest `confirmationRule` string.
- Test fixtures that build their own `.always` grants to test challenge mechanics are **not** modified. Guard-mechanics tests keep asserting the refusal — under an explicit `.structural` posture.
- No commit/push without an explicit go-ahead in the turn.

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G0-1 | `[policy]` ADR-064 written per template: both owner instructions verbatim (2026-09-15; 2026-09-16 D-2 override), decision incl. lifted-guard and kept-guard lists, non-transferable boundary, falsifiers, evidence class; D-1…D-6 `DECISION:` lines present | `ls docs/decisions/ADR-064-*.md`; `grep -c '^DECISION: D-[1-6]' ledger/PHASE_LEDGER.md` = 6 |
| G0-2 | `[policy]` `OwnerTrustPosture.isEnabled` introduced; the seven challenging grants derive `.none` from it; `OwnerTrustPostureTests` prove the switch is the only difference | `unit`: tests green; `grep -c 'confirmationRequirement: .always' DefaultPolicyGrants.swift` = 0 |
| G0-3 | `[policy]` Grant coverage: every capability named by `InitialCapabilitySet.manifests()` evaluates `.allow` with no challenge for `actor: .user`; any gap fixed with a seeded `.none` grant of the narrowest honest pattern | `unit`: `OwnerGrantCoverageTests` green; ledger lists each gap the test found |
| G0-4 | `[policy]` `ComputerUseGuardPosture` introduced (`.structural` / `.ownerTrust`; `.production` derived from `OwnerTrustPosture`); loop, executor, and screen engine take it with production defaults; `ComputerUseGuardPostureTests` prove each of A/B/C is lifted under `.ownerTrust` and refused under `.structural`; emergency stop stops both presets | `unit`: `AuraComputerUseTests` + `AuraScreenTests` green; `git diff` shows no change to `EmergencyStopController`, `emergencyStop.isActive` checks, identity-change, `maxIterations`, rate limit, `AuraKernel_Construction.swift` |
| G0-5 | Pinned-test updates are deliberate and cited; challenge- and guard-mechanics fixtures only gain an explicit `.structural` posture | `git diff --stat Tests/` reviewed; every changed assertion has an `ADR-064` comment (`grep -rn 'ADR-064' Tests/ \| wc -l` ≥ number of changed assertions) |
| G0-6 | Live: shell turn, coding-agent turn, app-terminate turn each complete with no confirmation card; audit shows `allow` with the seed grant ID; owner attestation recorded | `live-local` driver transcript + no card element; `owner-attested` line |
| G0-7 | Full verification + governance: suite ×2–3 green (22/22, 0 failed), ADR accepted, `PROJECT_LEDGER` append, `CURRENT_STATE` atomic rewrite | outputs captured under `evidence/PA-0/` |
| G0-8 | Machine coherence: validator OK, all gates `passed`, `phase_status: awaiting-approval` | `bash validate-continuity.sh` exit 0 |

## Per-gate procedure

- **G0-1:** Draft ADR-064 from `01-owner-trust-posture.md` §3.4. Quote the owner's 2026-09-15 instruction and the 2026-09-16 D-2 override verbatim. Cite ADR-055 as precedent. State explicitly what is *not* changed (§3.3/§3.3a "what stays").
- **G0-2:** Add `OwnerTrustPosture.swift`. Replace the seven literal requirements with the derived constants. Run `AuraPolicyTests` alone first, then fix pinned assertions.
- **G0-3:** Write the coverage test; iterate until green. Every new grant added gets a comment naming the gap and ADR-064. Re-run `AuraPolicyTests` + `AuraIntentTests`.
- **G0-4:** Add `ComputerUseGuardPosture.swift`; thread `guardPosture:` through `ComputerUseControlLoop` and `AXCGEventActionExecutor`, `sensitiveApplicationExclusionEnabled:` through `ScreenContextEngine`, all defaulting to production. Give existing guard-mechanics tests an explicit `.structural`. Write `ComputerUseGuardPostureTests`. Run `AuraComputerUseTests` + `AuraScreenTests`. Diff the kept list.
- **G0-5:** `git diff Tests/` line by line; confirm only assertions about *production seed* requirements changed and fixtures only gained the explicit posture.
- **G0-6:** Build bundle to a fresh path under `~/Library/Developer/AURA/pa0-<date>`, stable-sign, `verify-signature.sh`, `open -a`. Run the three turns through the driver; capture transcript; capture the absence of the confirmation card (add `AuraAccessibilityID.confirmationCard` if missing — this is an *addition* in `AuraAccessibilityIdentifiers.swift` and is the one exception to the allowed-files list, recorded in the ledger).
- **G0-7/G0-8:** Standard closing sequence (§2 of `08-rollout.md`).

## Evidence template (ledger entry)

```text
## SEQ-00NN — <ISO> — PA-0 — G0-k PASSED
- evidence: <file:line | command output lines | evidence/PA-0/<file>>
- verified: <exact command>
- adr: ADR-064   ← required for [policy] gates (A7)
```

## Risks / reverting

Reverting means restoring the allowed files from git and removing the new files; the store's seeded grants reconcile back on next launch (`reconcileSeededGrants`). If G0-3 finds a gap whose honest pattern is unclear, record it `blocked` with the capability name and ask the owner — do not seed `.any` for filesystem-class capabilities.

## Session script

Start: protocol §5 steps 1–7. Then G0-1 → G0-8 in order, one gate per checkpoint. End: `phase_status: awaiting-approval` and the question *"Faz PA-0 tamamlandı; geçiş için onayınız?"*

## Cognitive completion gate

Before declaring the phase done, answer in the ledger: (1) Which capability would still show a confirmation card, and why? (expected: none for the owner actor) (2) Which computer-use step would still halt for the owner, and why? (expected: only emergency stop, identity change, iteration ceiling) (3) Which kept guard did I verify is untouched, by diff? (4) Could another Mac inherit this posture by copying the build, and where is that forbidden in writing?
