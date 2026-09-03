# Cross-Review Request — review of Claude Code's work

> **How to use this:** open this repository in VS Code Copilot with the
> `deepseek-v4-flash` model and paste the "Task" section below. This closes the
> other half of the ADR-050 cross-review loop. Claude Code reviewed your SP-023 /
> SP-024 / SP-025 work; it **cannot** review its own, so `security` cannot close
> until someone else reads the artifacts listed here.
>
> **Updated 2026-09-01, still not executed as of that date.** Artifacts 1–3 are
> unchanged from the original 2026-08-30 request. **Artifact 4 is new** — it
> covers a second, later session's work (2026-08-31) that touches the policy
> authorization pipeline directly and has never been read by anyone independent
> either. Do all four (five, counting the optional one) in the same pass so this
> is one trip rather than two.

## Why you are the right reviewer

Under ADR-050, independence is defined by **authorship**. You authored SP-023,
SP-024 and SP-025. You did **not** author any artifact below — Claude Code wrote
Artifacts 1–3 in session `AURA-SP-030-BETA-EVIDENCE-20260830` and Artifact 4 in
session `AURA-SP-030-SLO-INSTRUMENTATION-20260831` — so you are independent of
all of them, and disclosing that you authored the code Claude Code reviewed
(SP-023/024/025) is the conflict-of-interest note your review must carry.

## Task

Perform an adversarial review of the artifacts below (four required, one
optional). Do not accept a claim because a comment or an evidence record
asserts it — check the call path, and where you suspect a defect, produce an
executable proof rather than an assertion.

### Artifact 1 — the F-001 remediation

`Sources/AuraCore/HelperIPCAuthentication.swift`, function
`HelperIPCAuthenticator.constantTimeEquals`, plus its regression tests in
`Tests/AuraCoreTests/HelperIPCAuthenticationTests.swift`.

Claude Code found that the previous implementation guarded on `String.count`
(grapheme count) and then indexed two UTF-8 **byte** arrays, so a hostile
64-character tag containing one multi-byte scalar trapped with `Index out of
range` — inside the authentication check, before authentication succeeded, on
attacker-controlled input. It changed the guard to compare byte counts.

Questions to answer:
1. Does the new implementation actually reject every length mismatch without
   trapping, for **both** operand orders? Try to construct an input that still traps.
2. Is the comparison still constant-time **for equal-length inputs**? Note it
   returns early on a length mismatch — is that acceptable here, given the right
   operand is always a fixed-length 64-char hex tag?
3. Do the two regression tests actually fail against the old implementation, or
   would they pass either way? (A regression test that cannot fail is not one.)
4. Is there any other place in the codebase that compares attacker-controlled
   strings using `String.count` before indexing bytes?

### Artifact 2 — the R12 readiness contract's measured mode

`scripts/validate_beta_readiness.py`, `archive/runtime-completion/schemas/beta-readiness.schema.json`,
and `scripts/tests/test_beta_readiness.py`.

Claude Code rewrote the validator so a completed beta is representable at all.
Its claim is that the measured mode is **not** a relaxation: every recorded result
must carry provenance, and a sign-off cannot be self-granted.

Questions to answer:
1. **Find a way to record a fabricated result that the validator accepts.** This
   is the main question. Try: a measurement with no evidence ID; a harness result
   presented as a live beta sample; a sample count below the declared minimum; a
   missing declared percentile; a sign-off without a named evaluator; a sign-off
   where `evaluator_is_implementing_agent` is absent rather than `false`; a
   scenario marked `passed` with an empty or malformed evidence ID.
2. Are the privacy invariants still unconditional in **every** mode —
   `telemetry.transport == "none"`, `raw_content_allowed == false`, no
   content-bearing aggregate field, `authority.release == false`, release
   candidate `blocked`?
3. Does the validator fail **closed** on unknown status values, or does any
   unrecognized value fall through a branch and get silently accepted?
4. Does `archive/runtime-completion/state/beta-readiness.json` as committed contain
   any claim stronger than its evidence supports?

### Artifact 3 — the F-005 localization remediation

`Sources/AURA/AuraMenuView_Tabs.swift` (`emergencyControls`), the five new
`emergency.*` keys in `Sources/AURA/ProductUIState.swift`, and the three tests in
`Tests/AURAIntegrationTests/AuraAccessibilityIdentifierTests.swift`
(`EmergencyControlLocalizationTests`).

Claude Code found that the emergency control — the control that stops generated
mouse and keyboard input — was entirely English, including both VoiceOver hints, so
a Turkish-speaking VoiceOver user was read English for it. It routed all five
strings through the existing `AuraCopy` table.

Questions to answer:
1. Are the Turkish strings actually correct and idiomatic Turkish? The reviewer
   wrote them and cannot judge its own translation. `"Acil Durdurma"`,
   `"Üretilen girdiyi anında devre dışı bırakır"`, `"Üretilen girdiyi yeniden
   etkinleştir"`, `"Üretilen fare ve klavye girdisine yeniden izin verir"`,
   `"Acil durum kontrolü"` — would a Turkish speaker under stress understand these?
2. Do the three regression tests actually fail against the pre-fix code, or would
   they pass either way?
3. Does any emergency-control string still bypass `copy(_:)`?
4. Claude Code left the **systemic** gap open — most other strings in
   `Sources/AURA` are still unlocalized. Is the claim that only the emergency
   instance was fixed accurately reflected in the evidence and risk register, or
   does anything overstate the remediation?

### Artifact 4 — the R11 lifecycle-capability authorization pipeline (2026-08-31, required)

Nine of eleven lifecycle capabilities (launch-at-login, safe mode, reset,
rollback, uninstall, factory reset, update check/stage/approve) were denied
before reaching their implementation, because the capability registry disabled
them citing a "reachable through direct `AuraKernel` RuntimeAPI calls" escape
hatch that did not actually work — no grant existed and the direct-call
confirmation path threw unconditionally. Under owner authorization, Claude Code
changed the **authorization pipeline itself** for exactly one capability,
`lifecycle.launchAtLogin`. This is squarely a security artifact, not a
convenience fix, and it has not been read by anyone independent.

Files:

- `Sources/AuraPolicy/DefaultPolicyGrants.swift` — new seeded grant:
  `Grant(capability: .lifecycleLaunchAtLogin, patterns: [.any], confirmationRequirement: .forRiskTier(.mutation), purpose: seedPurpose)`.
- `Sources/AuraCore/PolicyTypes_Capability.swift` — new capability
  `lifecycleLaunchAtLoginStatus` (`.observation` tier), split out of the write
  so a **read** no longer needs a `.mutation` confirmation.
- `Sources/AURA/AuraKernel_RuntimeAPI.swift` — `evaluateDirectCapability`'s
  `.confirm` case: previously threw unconditionally ("no confirmation
  presenter is wired for this direct-call path yet"); now calls
  `confirmationPresenter.present(challenge:)` then
  `policyEngine.submitConfirmation(response)`, mirroring the existing
  `ToolRouter_Policy` pattern. Also `isLaunchAtLoginEnabled()`, re-gated to the
  new observation capability.
- `Sources/AuraIntent/InitialCapabilitySet_CapabilityDefinitions.swift` — the
  `lifecycleDirectCallReason` string, corrected to stop asserting a
  reachability guarantee the code did not provide.
- `Sources/AURA/AuraAppModel_Interaction.swift` —
  `denyConfirmationIfStillPending()`: closing the Settings window (or any
  other dismissal of the confirmation surface) with a challenge still pending
  now denies it explicitly, rather than letting it lapse on its 60 s timer.
- `Sources/AURA/AuraMenuView.swift` — `AuraConfirmationCard` is now rendered as
  the first row of `AuraSettingsView`'s `Form` (a `.sheet` was tried and
  rejected — it did not present at all inside SwiftUI's `Settings` scene), and
  `.onDisappear { model.denyConfirmationIfStillPending() }` is attached to that
  view.
- Tests: `Tests/AuraPolicyTests/DefaultPolicyGrantsTests.swift` (5 new tests:
  `launchAtLoginIsReachable`, `destructiveLifecycleCapabilitiesStayDenied`,
  `exactlyOneLifecycleCapabilityIsSeeded`, `launchAtLoginStatusIsObservation`,
  `writeStillRequiresConfirmationAfterSplit`) and
  `Tests/AURAIntegrationTests/ConfirmationSheetFailClosedTests.swift` (3 tests:
  `dismissalDenies`, `answeredConfirmationIsNotReDenied`,
  `noPendingConfirmationIsNoOp`).

Questions to answer:
1. Does `evaluateDirectCapability`'s new `.confirm` handling actually verify
   the response before granting, or could a forged, replayed, or predictable
   `PolicyConfirmationResponse` be accepted without the card ever being
   answered by a user? Trace `PolicyEngine.submitConfirmation` yourself — does
   it check nonce, expected hash, and expiry against the **original**
   challenge, or could a stale response from an earlier, unrelated
   confirmation be replayed against a new one?
2. Is `patterns: [.any]` on the new grant appropriately scoped for this
   capability, or does it create any unintended broader authorization — could
   a call site construct a `PolicyTarget` that lets a *different* action ride
   through under this grant because the target isn't actually checked against
   anything?
3. The safety of `denyConfirmationIfStillPending()` depends entirely on
   `resolveConfirmation` clearing `pendingConfirmation` **before** any
   dismissal callback can run, so that accepting a confirmation makes the
   subsequent dismissal a no-op. Is that ordering actually guaranteed by
   SwiftUI's view-lifecycle and `@Published` delivery, or is there a
   plausible race — concurrent dismissal and acceptance, a different actor,
   a re-entrant call — where an **accepted** confirmation could be
   incorrectly denied after the fact, or a **denied** one incorrectly
   register as accepted?
4. Does splitting `lifecycleLaunchAtLoginStatus` (`.observation`, no
   confirmation) from `lifecycleLaunchAtLogin` (`.mutation`, confirmed) leak
   anything through the read path that the write path is supposed to gate?
   Could the read path be induced to trigger any side effect at all — should
   be a pure query with zero mutation?
5. `AuraKernel.confirmationPresenter` is a single shared instance used by both
   the NLU-driven `ToolRouter_Policy` path and this new direct-call path. Is
   there any way two concurrently pending confirmations — one from each path —
   could be cross-matched, so a user answering the card they see actually
   resolves a *different* pending request than the one displayed?
6. Do the eight new tests listed above actually fail against the pre-fix code
   (i.e., are they real regression tests), or would some of them pass either
   way?
7. Nine of eleven lifecycle capabilities remain deny-by-default on purpose
   (destructive/network tier). Confirm none of this change widens any of the
   other eight — `destructiveLifecycleCapabilitiesStayDenied` claims to pin
   this; does it actually exercise all eight, or does it silently skip any?

### Artifact 5 (optional, lower priority) — the `ptt_ack` SLO contamination fix

`Sources/AURA/AuraAppModel_Interaction.swift`,
`AuraAppModel.pushToTalkAckSample(pressedAt:acknowledgedAt:promptedForPermissions:)`,
and `Tests/AURAIntegrationTests/PushToTalkAckSampleTests.swift`. Not an
authorization defect — a measurement-integrity one: the pre-fix code recorded
the user's reaction time to a permission dialog as machine latency for the
`ptt_ack` SLO. Only worth your time if Artifact 4 turns up nothing and you have
capacity left: does the fix genuinely exclude every turn that raised the OS
permission prompt, and do the tests actually fail against the pre-fix logic?

## What to produce

**Append your findings directly to
`docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md`** as a new section at
the end of the file, titled exactly:

```markdown
## Round 4 — 2026-09-01 — cross-agent independent review (Artifact 4 continuation)
```

Match the structure Round 2 already established in that file (read it before
you write — it is the template): a blockquote header with **Reviewer**,
**Conflict of interest (disclosed)**, and **Method** lines; a `## Findings`
table (`ID | Area | Severity | Status | Owner | Closure evidence`); one
`### F-0XX (Severity, status) — title` block per finding, each with a
reproduction (command, input, observed output) — **continue the numbering from
F-007** (F-001–F-006 already exist in that file, do not reuse them); a
`## Reviewed with no finding` section; and a `## Limitations` section stating
exactly what you did and did not exercise (no live app run, no signed binary,
static/source review only — unless you actually did more, in which case say
so).

If your VS Code Copilot session can write files directly, write that section
into the file yourself. If it cannot, paste your raw findings back into this
conversation and Claude Code will append them **verbatim, unedited** under the
same heading — editing an independent reviewer's own words would defeat the
point of the review.

Do **not** mark any sign-off obtained. Sign-offs are recorded separately against
`beta-readiness.json` by the agent holding the owner's instruction, and only
after both directions of this cross-review exist.
