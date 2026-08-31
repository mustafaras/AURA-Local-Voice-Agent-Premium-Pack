# Cross-Review Request — review of Claude Code's work

> **How to use this:** open this repository in VS Code Copilot with the
> `deepseek-v4-flash` model and paste the "Task" section below. This closes the
> other half of the ADR-050 cross-review loop. Claude Code reviewed your SP-023 /
> SP-024 / SP-025 work; it **cannot** review its own, so `security` cannot close
> until someone else reads the two artifacts listed here.

## Why you are the right reviewer

Under ADR-050, independence is defined by **authorship**. You authored SP-023,
SP-024 and SP-025. You did **not** author the two artifacts below — Claude Code
wrote them in session `AURA-SP-030-BETA-EVIDENCE-20260830` — so you are
independent of them, and disclosing that you authored the code Claude Code
reviewed is the conflict-of-interest note your review must carry.

## Task

Perform an adversarial review of exactly two artifacts. Do not review anything
else. Do not accept a claim because a comment or an evidence record asserts it —
check the call path, and where you suspect a defect, produce an executable proof
rather than an assertion.

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

`scripts/validate_beta_readiness.py`, `AURA_RUNTIME_COMPLETION/schemas/beta-readiness.schema.json`,
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
4. Does `AURA_RUNTIME_COMPLETION/state/beta-readiness.json` as committed contain
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

## What to produce

A findings list in the format of
`docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md`, with:
- your COI disclosure (you authored SP-023/024/025, which Claude Code reviewed);
- severity per finding;
- for each finding, a reproduction — command, input, observed output;
- explicitly, the areas you checked and found **no** defect, so the coverage is legible.

Do **not** mark any sign-off obtained. Sign-offs are recorded separately against
`beta-readiness.json` by the agent holding the owner's instruction, and only after
both directions of this cross-review exist.
