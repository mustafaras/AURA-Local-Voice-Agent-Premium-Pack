# PA-0: Owner Trust Posture — ending the confirmation loop

**Phase:** PA-0. **Effort:** S–M. **ADR:** ADR-064 (new) — "Owner-directed personal-assistant posture".
**Owner instruction covered:** "onaylara ve tekrar tekrar izinlere gerek yok" (in-app approvals half; OS permissions are PA-1).

---

## 1. Evidence (what the code does today)

| Fact | Evidence |
| --- | --- |
| Seven grants still challenge the owner | `Sources/AuraPolicy/DefaultPolicyGrants.swift` — `.always`: `shellExec`, `agentCodexRun`, `agentClaudeRun`, `agentCopilotRun`, `agentOllamaCloudInference`; `.forRiskTier(.mutation)`: `appTerminate`, `lifecycleLaunchAtLogin`, `computerUseRun` (grep `confirmationRequirement:`; 25 `Grant(` in file) |
| Any ungranted capability in four tiers is denied | `PolicyTypes_PolicyConfiguration.swift:31` `denyByDefaultTiers = [.reversible, .mutation, .destructive, .network]`; `PolicyEngine_Evaluation.swift:44-52` deny path; the repo hit this silently for filesystem (SP-006) and launch-at-login (SP-030) — `DefaultPolicyGrants.swift:11-31,108-118` |
| Seeding reconciles, never appends | `AuraKernel_Grants.swift:23-37` (`reconcileSeededGrants`, marker `DefaultPolicyGrants.seedPurpose`) — a seed-list change migrates existing stores on next launch |
| Confirmation surface | `UIConfirmationPresenter.swift:34-56` (`UIConfirmationPresenter` actor, expiry-checked); card in `AuraConfirmationCard`; fail-closed dismissal `AuraAppModel_Interaction.swift:225-249`; a demo-only `AutoAllowConfirmationPresenter` gated by `AURA_TEXT_DEMO_SCRIPT` (`UIConfirmationPresenter.swift:21-31`) |
| Precedent for owner waivers | ADR-055 §2 seeded nine destructive lifecycle capabilities with `confirmationRequirement: .none` as "an owner-instructed local risk acceptance … not a transferable policy default" |
| Tests that pin the current posture | `Tests/AuraPolicyTests/PolicyEngineTests.swift`, `PolicyEngineTests_MoreTests.swift:41` (shellExec `.always`), `Tests/AURAIntegrationTests/SP003LiveBilingualDialogueScenarios.swift:143` (comments on production `.always`), `SP006LiveCapabilityScenarios.swift`, `Tests/AuraAgentTests/{Claude,Codex,Copilot}TaskRunnerTests*.swift`, `OllamaAdapterTests.swift` |

## 2. Problem statement

For a single owner behind a login password, a confirmation card on "run `ls`", on every coding-agent turn, on every cloud inference, and on every computer-use mutation action is not a safety control — it is a second password. The owner has stated that the login is the authorization. The engine must answer `.allow` for the owner actor on every registered capability, while continuing to evaluate, audit, and enforce structural guards.

## 3. Design

### 3.1 One switch, one ADR

Introduce `OwnerTrustPosture` in `AuraPolicy` (a `public enum` with `static let isEnabled = true` and a doc comment citing ADR-064). It is a *compile-time* posture for this local build, not a runtime toggle — a runtime toggle would be one more thing to be asked about. `DefaultPolicyGrants` derives every `confirmationRequirement` from it:

```swift
// DefaultPolicyGrants.swift
private static let ownerConfirmation: ConfirmationRequirement =
  OwnerTrustPosture.isEnabled ? .none : .always
private static let ownerMutationConfirmation: ConfirmationRequirement =
  OwnerTrustPosture.isEnabled ? .none : .forRiskTier(.mutation)
```

and the seven grants above use those constants. The ADR-055 comment block stays; a new ADR-064 comment records the widening.

### 3.2 Grant coverage is proven, not assumed

New test `OwnerGrantCoverageTests` (in `Tests/AuraPolicyTests` — `AuraPolicy` can import `AuraIntent`? verify; if not, place in `Tests/AURAIntegrationTests`): for every `(manifest, _)` in `InitialCapabilitySet.manifests()`, for every `Capability` the manifest's permission set names, evaluate `PolicyEngine` with `actor: .user` against a fresh in-memory store seeded with `DefaultPolicyGrants.all`, and assert the decision is `.allow` with **no** challenge. Any failure names the capability; the fix is a seeded grant with `confirmationRequirement: .none` and the narrowest honest pattern (e.g. filesystem grants stay scoped to `DeclaredFileRoots`). This closes the recurring SP-006/SP-030 class permanently.

Expected gaps to surface (from the risk-tier scan of `PolicyTypes_Capability.swift`): VS Code `runTask` / `cancelTask` / `runTests` / `cancelTests` / `injectTerminal` (reversible/mutation), plugin `enable`/`install`/`manageExtension`, `screen.capture` is observation (allowed). The test decides; this list is a prediction, not evidence.

### 3.3 What the confirmation surface becomes

- `UIConfirmationPresenter`, `AuraConfirmationCard`, and the fail-closed dismissal path stay in the codebase: they still serve `actor: .plugin` (`PolicyEngine_Evaluation.swift:37-42` denies plugins without a grant; a future plugin grant may carry `.confirm`) and the emergency-stop re-arm flow.
- `AutoAllowConfirmationPresenter` remains demo-only; PA-0 does **not** route production through it.
- The Capabilities tab's "Onay / risk" line (`AuraMenuView_Tabs.swift:137-139`) keeps rendering `manifest.confirmationRule`. Those strings ("mutation tier default (confirmation required unless granted)") remain *true* — the grant is what removes the confirmation. No manifest text changes.

### 3.4 ADR-064 contents (outline)

Context (owner instruction verbatim; ADR-055 precedent; login-as-boundary), Decision (§3.1–3.3), Boundaries (non-transferable; falsified by any build that ships this posture to another user/device; ADR-049 unchanged), Falsifiers (any record calling this a default; any test that relabels this as multi-user-safe), Evidence class (unit + live-local).

## 4. Files touched (scope guard)

`Sources/AuraPolicy/DefaultPolicyGrants.swift`, `Sources/AuraPolicy/OwnerTrustPosture.swift` (new), the pinned tests in §1 (deliberate, ADR-cited updates), `Tests/…/OwnerGrantCoverageTests.swift` (new), `docs/decisions/ADR-064-owner-trust-posture.md` (new), repo ledgers. **Nothing else** — in particular no change to `PolicyEngine_Evaluation.swift`, `PolicyConfiguration` tiers, computer-use guards, or `EmergencyShortcutMonitor`.

## 5. Tests

- **New:** `OwnerTrustPostureTests` (every seeded grant resolves to `.none` when posture enabled; the seven named grants resolve to their pre-PA-0 values when disabled — proves the switch is the only difference). `OwnerGrantCoverageTests` (§3.2).
- **Updated (ADR-documented):** the pinned `.always` expectations in `PolicyEngineTests*`, `SP003…`, `SP006…`, agent task-runner tests, `OllamaAdapterTests` — each updated assertion cites ADR-064 in a comment. Test *fixtures* that construct their own grants with `.always` to exercise the challenge mechanics are **not** changed (the mechanism must keep working).
- **Unchanged and must stay green:** confirmation-transaction correctness tests (ADR-037), emergency-stop tests, computer-use guard tests, reducer determinism, copy-table guard, a11y-ID tests.

## 6. Live acceptance (driver + owner attestation)

1. Typed turn `ls ~` → `shell.execute_typed` completes; driver asserts no element with identifier `AuraAccessibilityID.confirmationCard` (add the ID if absent — check `AuraAccessibilityIdentifiers.swift`) appears within 3 s; response bubble present.
2. Typed turn that routes to a coding-agent run (`claude -p` smoke, per repo precedent) → no card; audit event shows `decision=allow grantID=<seed>`.
3. Typed turn "Notes'u kapat" (`app.terminate`) → no card; app terminated.
4. Owner attestation line: "hiçbir onay kartı çıkmadı" recorded verbatim.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| A grant pattern is too narrow and a capability is still denied in a real utterance | G0-3 coverage test iterates *manifests*, not utterances; G0-4 live legs cover the three most-used paths; PA-6 soak catches the rest |
| Reconciliation prunes an owner-created grant | `reconcileSeededGrants` prunes only grants carrying `seedPurpose`; verify by unit test before shipping |
| Someone copies this build to another Mac | ADR-064 falsifier + `OwnerTrustPosture` doc comment + ADR-049 (local-only) — this is a documented, non-transferable waiver |

## 8. Owner decisions consumed

D-1 (confirmation semantics), D-2 (guards stay).
