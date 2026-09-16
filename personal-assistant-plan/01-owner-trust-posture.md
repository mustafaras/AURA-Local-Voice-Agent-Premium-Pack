# PA-0: Owner Trust Posture — ending the confirmation loop

**Phase:** PA-0. **Effort:** S–M. **ADR:** ADR-064 (new) — "Owner-directed personal-assistant posture".
**Owner instruction covered:** "onaylara ve tekrar tekrar izinlere gerek yok" (in-app approvals half; OS permissions are PA-1) **and, per D-2 as resolved on 2026-09-16, "computer use koruması istemiyorum"** — the computer-use structural guards are lifted for the owner posture, emergency stop excepted.

---

## 1. Evidence (what the code does today)

| Fact | Evidence |
| --- | --- |
| Seven grants still challenge the owner | `Sources/AuraPolicy/DefaultPolicyGrants.swift` — `.always`: `shellExec`, `agentCodexRun`, `agentClaudeRun`, `agentCopilotRun`, `agentOllamaCloudInference`; `.forRiskTier(.mutation)`: `appTerminate`, `lifecycleLaunchAtLogin`, `computerUseRun` (grep `confirmationRequirement:`; 25 `Grant(` in file) |
| Any ungranted capability in four tiers is denied | `PolicyTypes_PolicyConfiguration.swift:31` `denyByDefaultTiers = [.reversible, .mutation, .destructive, .network]`; `PolicyEngine_Evaluation.swift:44-52` deny path; the repo hit this silently for filesystem (SP-006) and launch-at-login (SP-030) — `DefaultPolicyGrants.swift:11-31,108-118` |
| Seeding reconciles, never appends | `AuraKernel_Grants.swift:23-37` (`reconcileSeededGrants`, marker `DefaultPolicyGrants.seedPurpose`) — a seed-list change migrates existing stores on next launch |
| Confirmation surface | `UIConfirmationPresenter.swift:34-56` (`UIConfirmationPresenter` actor, expiry-checked); card in `AuraConfirmationCard`; fail-closed dismissal `AuraAppModel_Interaction.swift:225-249`; a demo-only `AutoAllowConfirmationPresenter` gated by `AURA_TEXT_DEMO_SCRIPT` (`UIConfirmationPresenter.swift:21-31`) |
| Precedent for owner waivers | ADR-055 §2 seeded nine destructive lifecycle capabilities with `confirmationRequirement: .none` as "an owner-instructed local risk acceptance … not a transferable policy default" |
| Computer-use structural guards (lifted by D-2) | (A) `Sources/AuraCore/ComputerUseTypes.swift:64-71` `mandatoryConfirmationIntents` + `Sources/AuraComputerUse/ComputerUseControlLoop_Run.swift:304-319` terminal `.mandatoryConfirmationBlocked` on a bare `.allow`; (B) secure-field refusal `ComputerUseControlLoop_Run.swift:354-382` and `UIActionExecuting.swift:127-140`, sensitive-application exclusion `Sources/AuraScreen/ScreenContextEngine.swift:249-259` over `Configuration_ScreenContextConfiguration.swift:50-59`; (C) unexpected-modal halt `ComputerUseControlLoop_Run.swift:195-213`, no-progress halt `:119-122`, per-plan step ceiling `:143-153` |
| Kept (D-2 exception and bounds) | Emergency stop `EmergencyStopController.swift`, checked at `ComputerUseControlLoop_Run.swift:88,337` and `UIActionExecuting.swift:108`; identity-change detection `:100-109,338-344`; `maxIterations` `:66-79`; action rate limit `:383-391` |
| Tests that pin the current posture | `Tests/AuraPolicyTests/PolicyEngineTests.swift`, `PolicyEngineTests_MoreTests.swift:41` (shellExec `.always`), `Tests/AURAIntegrationTests/SP003LiveBilingualDialogueScenarios.swift:143` (comments on production `.always`), `SP006LiveCapabilityScenarios.swift`, `Tests/AuraAgentTests/{Claude,Codex,Copilot}TaskRunnerTests*.swift`, `OllamaAdapterTests.swift`; guard mechanics: `Tests/AuraComputerUseTests/ComputerUseControlLoopTests*.swift`, `R4AdversarialSafetyTests.swift`, `R4DetectorFailClosedTests.swift`, `UIActionExecutingTests.swift`, `Tests/AuraScreenTests/ScreenContextEngineTests*.swift` |

## 2. Problem statement

For a single owner behind a login password, a confirmation card on "run `ls`", on every coding-agent turn, on every cloud inference, and on every computer-use mutation action is not a safety control — it is a second password. The owner has stated that the login is the authorization. The engine must answer `.allow` for the owner actor on every registered capability, while continuing to evaluate and audit every call.

D-2 (resolved 2026-09-16) extends the same reasoning to computer use: for the owner, a session that *stops itself* on "send", "delete", or "purchase", refuses to act while a password field is focused, refuses to look at a password manager, or halts on a modal dialog is the same second password in another shape. The owner accepted the consequence in writing: with these guards off, a computer-use session is bounded only by the planner, the policy engine's grants, identity-change detection, the iteration ceiling, and the emergency stop.

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

### 3.3a Computer-use guard posture (D-2, resolved 2026-09-16)

A second derived value, `ComputerUseGuardPosture` in `AuraComputerUse`, carries five booleans — `enforcesMandatoryConfirmation` (A), `refusesSecureFields` (B), `haltsOnUnexpectedModal`, `haltsOnNoProgress`, `enforcesMaxStepsPerPlan` (C) — with two named presets: `.structural` (all true, the pre-PA-0 behaviour) and `.ownerTrust` (all false). `ComputerUseGuardPosture.production` is `OwnerTrustPosture.isEnabled ? .ownerTrust : .structural`. `ComputerUseControlLoop` and `AXCGEventActionExecutor` take a `guardPosture:` parameter defaulting to `.production`; `ScreenContextEngine` takes `sensitiveApplicationExclusionEnabled:` defaulting to `!OwnerTrustPosture.isEnabled`. The production kernel wiring passes nothing and inherits the defaults, so the posture switch is the only thing that decides.

What each lifted guard does under `.ownerTrust`:

- (A) A step whose intent is in `mandatoryConfirmationIntents` executes on a bare `.allow` like any other step. The policy engine's own `.confirm` decision is still honoured (it cannot occur for the owner after §3.1, but the branch is not removed).
- (B) The loop and the executor skip the secure-field probe entirely (no probe means no `.indeterminate` refusal either). `ScreenContextEngine.exclusionReason` no longer consults `sensitiveApplicationBundleIdentifiers`; `assistantSelfExclusion`, `windowNotVisible`, redaction, and zero retention are unchanged.
- (C) The modal probe is skipped; the no-progress counter is still computed and emitted in `ComputerUseVerifyEvent` but never terminates the run; a plan longer than `maxStepsPerPlan` executes in full.

What stays under both presets, by design and by diff: `EmergencyStopController` and every `emergencyStop.isActive` check (D-2 exception), identity-change detection, invalid-anchor rejection, the `maxIterations` ceiling (a resource bound — the owner's only automatic stop when a planner never converges), the action rate limit, Accessibility-trust check, and the redaction pipeline.

Doc comments that state the old invariant (`ComputerUseTypes.swift:59-63` "no `Grant`, however permissively configured, can cause…", `Configuration_ComputerUseConfiguration.swift:4-8`) are corrected in place — comment-only edits — so the source does not lie about the posture.

### 3.4 ADR-064 contents (outline)

Context (owner instructions verbatim — 2026-09-15 and the 2026-09-16 D-2 override; ADR-055 precedent; login-as-boundary), Decision (§3.1–3.3a, including the lifted-guard list and the kept list), Boundaries (non-transferable; falsified by any build that ships this posture to another user/device; ADR-049 unchanged), Falsifiers (any record calling this a default; any test that relabels this as multi-user-safe), Evidence class (unit + live-local).

## 4. Files touched (scope guard)

`Sources/AuraPolicy/DefaultPolicyGrants.swift`, `Sources/AuraPolicy/OwnerTrustPosture.swift` (new), `Sources/AuraComputerUse/ComputerUseGuardPosture.swift` (new), `Sources/AuraComputerUse/ComputerUseControlLoop.swift`, `ComputerUseControlLoop_Run.swift`, `UIActionExecuting.swift`, `Sources/AuraScreen/ScreenContextEngine.swift` (posture parameter + guarded branches only), comment-only corrections in `Sources/AuraCore/ComputerUseTypes.swift` and `Configuration_ComputerUseConfiguration.swift`, the pinned tests in §1 (deliberate, ADR-cited updates; guard-mechanics fixtures gain an explicit `guardPosture: .structural` / `sensitiveApplicationExclusionEnabled: true` and are otherwise untouched), `Tests/…/OwnerGrantCoverageTests.swift`, `OwnerTrustPostureTests.swift`, `ComputerUseGuardPostureTests.swift` (new), `docs/decisions/ADR-064-owner-trust-posture.md` (new), repo ledgers. **Nothing else** — in particular no change to `PolicyEngine_Evaluation.swift`, `PolicyConfiguration` tiers, `EmergencyStopController`, `EmergencyShortcutMonitor`, `UIConfirmationPresenter` wiring, or any manifest `confirmationRule` string.

## 5. Tests

- **New:** `OwnerTrustPostureTests` (every seeded grant resolves to `.none` when posture enabled; the seven named grants resolve to their pre-PA-0 values when disabled — proves the switch is the only difference). `OwnerGrantCoverageTests` (§3.2).
- **New (D-2):** `ComputerUseGuardPostureTests` — under `.ownerTrust`: a `.send` step executes on `.allow`; a focused secure field does not block the loop or the executor; an unexpected modal does not terminate; N identical observations do not produce `.noProgress`; a plan longer than `maxStepsPerPlan` executes; a sensitive-application window is listed and captured. Under `.structural`: each of the six is refused exactly as before (the existing guard tests, now constructed with `.structural`, are that proof). Emergency stop stops the loop and the executor under **both** presets.
- **Updated (ADR-documented):** the pinned `.always` expectations in `PolicyEngineTests*`, `SP003…`, `SP006…`, agent task-runner tests, `OllamaAdapterTests` — each updated assertion cites ADR-064 in a comment. Test *fixtures* that construct their own grants with `.always` to exercise the challenge mechanics are **not** changed (the mechanism must keep working).
- **Unchanged and must stay green:** confirmation-transaction correctness tests (ADR-037), emergency-stop tests (both presets), reducer determinism, copy-table guard, a11y-ID tests. Computer-use guard-mechanics tests stay green with `guardPosture: .structural` supplied explicitly.

## 6. Live acceptance (driver + owner attestation)

1. Typed turn `ls ~` → `shell.execute_typed` completes; driver asserts no element with identifier `AuraAccessibilityID.confirmationCard` (add the ID if absent — check `AuraAccessibilityIdentifiers.swift`) appears within 3 s; response bubble present.
2. Typed turn that routes to a coding-agent run (`claude -p` smoke, per repo precedent) → no card; audit event shows `decision=allow grantID=<seed>`.
3. Typed turn "Notes'u kapat" (`app.terminate`) → no card; app terminated.
4. Owner attestation line: "hiçbir onay kartı çıkmadı" recorded verbatim.
5. Computer-use guard lifting is proven at `unit` class in PA-0 (the loop and executor are deterministic under fakes); a live computer-use leg with a `send`-class step belongs to PA-6's soak, where a real target app and a granted Accessibility/Screen Recording hardware session exist. This is recorded as a boundary, not passed as live evidence.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| A grant pattern is too narrow and a capability is still denied in a real utterance | G0-3 coverage test iterates *manifests*, not utterances; G0-4 live legs cover the three most-used paths; PA-6 soak catches the rest |
| Reconciliation prunes an owner-created grant | `reconcileSeededGrants` prunes only grants carrying `seedPurpose`; verify by unit test before shipping |
| With the guards lifted, a planner step sends, deletes, purchases, or types into a credential field without any stop | Owner accepted in writing (D-2, 2026-09-16); emergency stop remains at loop and executor layers; `maxIterations` still bounds a runaway session; ADR-064 lists this as the posture's accepted consequence and its first falsifier if ever presented as a default |
| Someone copies this build to another Mac | ADR-064 falsifier + `OwnerTrustPosture` doc comment + ADR-049 (local-only) — this is a documented, non-transferable waiver |

## 8. Owner decisions consumed

D-1 (confirmation semantics), D-2 (resolved 2026-09-16: computer-use guards A/B/C lifted, emergency stop stays).
