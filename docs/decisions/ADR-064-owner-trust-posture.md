# ADR-064: Owner Trust Posture — No Confirmation Loop, Computer-Use Guards Lifted

- Status: Accepted — PA-0 unit + live verification complete 2026-09-16 (full suite 22/22 ×3; three driver turns with no confirmation card on the stable-signed bundle); the owner's attestation line for G0-6 is the one outstanding evidence item and is recorded in the PA ledger when given
- Date: 2026-09-16
- Owners: Personal Assistant track (PA-0) / release owner (user)
- Supersedes: none (amends the confirmation posture recorded by ADR-055 §1–§2 and the
  computer-use guard set recorded by ADR-019 and ADR-039; ADR-049 local-only remains in force)
- Superseded by: —

## Context

AURA was built as a cautious product for an unknown user. After ADR-055 the
seed set (`Sources/AuraPolicy/DefaultPolicyGrants.swift`) still challenged
the owner on eight grants — `.always` on `shell.exec`, `agent.codexRun`,
`agent.claudeRun`, `agent.copilotRun`, `agent.ollamaCloudInference`;
`.forRiskTier(.mutation)` on `app.terminate`, `lifecycle.launchAtLogin`,
`computerUse.run` — and the production `PolicyConfiguration` denies the
`.reversible`, `.mutation`, `.destructive`, and `.network` tiers by default
(`PolicyTypes_PolicyConfiguration.swift:31`), so any registered capability
without a seeded grant was silently denied (the SP-006 and SP-030 class of
defect). Independently of the policy engine, the computer-use control loop
carried structural guards that halt a session on their own: a fixed
mandatory-confirmation intent set (`ComputerUseTypes.swift:64-71`, enforced at
`ComputerUseControlLoop_Run.swift:304-319`), secure-field refusal in the loop
and in the executor (`ComputerUseControlLoop_Run.swift:354-382`,
`UIActionExecuting.swift:127-140`), the screen-context sensitive-application
exclusion (`ScreenContextEngine.swift:249-259`), the unexpected-modal halt
(`ComputerUseControlLoop_Run.swift:195-213`), the no-progress halt (`:119-122`),
and the per-plan step ceiling (`:143-153`).

The release owner directed, verbatim:

- 2026-09-15: "bence önce bu surekli izin onay parola döngüsünü kaldıralım
  bilgisayar açılışıyla birlikte uygulama çalışsın ve bilgisayar ztn parola
  ile açılıyor ve aura kişisel bi asıstan yani onaylara ve tekrar tekrar
  izinlere gerek yok ve yeteneklerde hiçbir YETENEK KESİNLIKLE DEVRE DIŞI
  OLMAMALI HER ZAMAN ETKİN HERGÖREV İÇİN ASİSTAN HAZIR OLMALI …"
- 2026-09-16, opening PA-0: "ONAY PA-0 — D-1..D-6 önerildiği gibi", then
  overriding the D-2 recommendation ("keep the structural guards"):
  "d 2 kalsın değil computer use koruması istemiyorum", and choosing from the
  four scopes offered: "A + B + C — acil durdurma hariç hepsi".

The owner's stated model is that the macOS login password is the
authentication boundary and AURA is a personal assistant inside it. For a
single owner behind that login, a confirmation card on `ls`, on every
coding-agent turn, on every cloud inference, and a computer-use session that
stops itself on "send" or refuses to act next to a password field are not
safety controls — they are a second password. ADR-055 already recorded the
precedent for this route: an owner-instructed, non-transferable local risk
acceptance implemented through seeded grants, not through a bypass of the
engine.

## Decision

1. **One compile-time posture switch.** `OwnerTrustPosture.isEnabled`
   (`Sources/AuraPolicy/OwnerTrustPosture.swift`, `public enum`, `static let
   isEnabled = true`) is the single source of the owner posture for this local
   build. It is deliberately not a runtime toggle: a toggle is one more thing
   to be asked about, and a persisted toggle could be flipped by a copied
   store. Every widened default below derives from this constant; nothing
   else in the codebase hard-codes the widened value.

2. **Seeded grants never challenge the owner.** `DefaultPolicyGrants`
   derives two constants — `ownerConfirmation` (`.none` when enabled, else
   `.always`) and `ownerMutationConfirmation` (`.none` when enabled, else
   `.forRiskTier(.mutation)`) — and the eight grants named above use them.
   With the posture enabled, `grep -c 'confirmationRequirement: .always'`
   over the file is zero. The engine still evaluates and audits every
   request; the grant is what changes its answer (D-1).

3. **Grant coverage is proven, not assumed.** `OwnerGrantCoverageTests`
   evaluates, for every capability that `InitialCapabilitySet.manifests()`
   names, a `PolicyEngine` seeded with `DefaultPolicyGrants.all` for
   `actor: .user`, and asserts `.allow` with no challenge. Any gap the test
   surfaces is closed with a seeded `.none` grant of the narrowest honest
   pattern (filesystem grants stay confined to `DeclaredFileRoots`). This
   closes the SP-006 / SP-030 class permanently: a capability that is
   registered but denied before its implementation is now a failing test.

4. **Computer-use structural guards are lifted for the owner posture
   (D-2 as resolved 2026-09-16).** `ComputerUseGuardPosture`
   (`Sources/AuraComputerUse/ComputerUseGuardPosture.swift`) carries five
   flags with two named presets — `.structural` (all enforced; the pre-PA-0
   behaviour) and `.ownerTrust` (none enforced) — and
   `ComputerUseGuardPosture.production` is `OwnerTrustPosture.isEnabled ?
   .ownerTrust : .structural`. `ComputerUseControlLoop` and
   `AXCGEventActionExecutor` take `guardPosture:` defaulting to
   `.production`; `ScreenContextEngine` takes
   `sensitiveApplicationExclusionEnabled:` defaulting to
   `!OwnerTrustPosture.isEnabled`. The kernel passes nothing and inherits the
   defaults. Under `.ownerTrust`:
   - (A) A step whose intent is in `mandatoryConfirmationIntents` (`send`,
     `publish`, `purchase`, `delete`, `deploy`, `acceptLegalTerms`,
     `authenticateOrChangeCredential`) executes on a bare `.allow` decision
     like any other step. The engine's own `.confirm` decision branch is kept
     and still honoured.
   - (B) The loop and the executor skip the secure-field probe entirely, so
     neither `.focused` nor `.indeterminate` refuses a step.
     `ScreenContextEngine.exclusionReason` no longer consults
     `sensitiveApplicationBundleIdentifiers`; the configured list is retained
     for the disabled posture.
   - (C) The modal probe is skipped; the no-progress counter is still
     computed and emitted in `ComputerUseVerifyEvent` but never terminates a
     run; a plan longer than `maxStepsPerPlan` executes in full.

5. **What is kept, by decision and by diff.** The owner's explicit exception
   is the emergency stop: `EmergencyStopController`, every
   `emergencyStop.isActive` check in the loop and the executor, and
   `EmergencyShortcutMonitor` are untouched and stop both presets. Also
   unchanged: `PolicyEngine_Evaluation.swift` and the deny-by-default tiers;
   identity-change detection (the loop still stops when the front application
   changes); invalid-anchor rejection; the `maxIterations` ceiling — with the
   no-progress halt lifted this is the owner's only automatic stop for a
   planner that never converges; the action rate limit; the Accessibility
   trust check; the screen-context redaction pipeline and zero raw-frame
   retention (ADR-018); the prompt-injection classifier; the network
   allowlist; `UIConfirmationPresenter`, `AuraConfirmationCard`, and the
   fail-closed dismissal path (they still serve `actor: .plugin` and the
   emergency-stop re-arm flow); `AutoAllowConfirmationPresenter` stays
   demo-only; every manifest `confirmationRule` string (they describe the
   tier default, which remains true — the grant is what removes the
   confirmation).

6. **Non-transferable boundary.** This is an owner-instructed local risk
   acceptance for a single, password-protected Mac under ADR-049 (local-only,
   no Developer ID, no external distribution). It is not a product default.
   A build that ships `OwnerTrustPosture.isEnabled == true` to another user
   or device, or a record that describes this posture as "the default" or as
   "multi-user-safe", falsifies this ADR.

## Alternatives considered

- **Runtime toggle in Settings.** Rejected: it reintroduces a question, and
  a persisted toggle can be copied with the store. A compile-time constant
  with a doc comment naming this ADR is the smallest honest surface.
- **Route production through `AutoAllowConfirmationPresenter`.** Rejected:
  it would bypass the engine's decision rather than change it, contradicting
  `AGENTS.md` ("Never bypass the permission engine for convenience") and
  leaving the audit trail recording challenges that were auto-answered.
- **Delete the guard code.** Rejected: the mechanism must keep working for
  `actor: .plugin`, for the disabled posture, and for the tests that prove
  it. Deriving from one switch keeps the code, the tests, and the revert path.
- **Lift A only, keep B and C** (the recommendation). Offered to the owner
  with the consequences of each scope; the owner chose A + B + C with the
  emergency stop kept.

## Security and privacy impact

- The engine still evaluates and audits every capability call; no call path
  skips `PolicyEngine`. What changes is the answer for `actor: .user`.
- Accepted consequences, stated plainly: a computer-use step may send,
  publish, purchase, delete, deploy, accept legal terms, or change a
  credential without a stop; AURA may synthesize input while a password
  field is focused; screen context may capture password-manager and
  security-agent windows (still redacted, still not retained). Shell,
  coding-agent, and cloud-inference turns run without a card.
- The emergency stop remains the owner's kill switch at both the loop and
  the executor layer.
- The prompt-injection classifier, network allowlist fail-closed behaviour,
  privilege separation across helpers (ADR-034/044), redaction, and zero
  retention are unchanged.
- Nothing here is release, notarization, beta, or distribution evidence
  (ADR-049, ADR-053 falsifiers apply).

## Operational impact

- `reconcileSeededGrants` migrates existing stores on next launch: the
  seeded set is replaced, not appended, so the previous `.always` /
  `.forRiskTier` seeds do not linger.
- Reverting is `OwnerTrustPosture.isEnabled = false` (or restoring the
  allowed files from git and removing the new ones); the seeded grants
  reconcile back and every guard returns under `.structural`.
- `AURA_TEXT_DEMO_SCRIPT` behaviour is unchanged.

## Migration

No schema change. No manifest change. Existing persisted grants carrying
`DefaultPolicyGrants.seedPurpose` are replaced at next kernel construction.

## Validation evidence

Recorded gate by gate in `personal-assistant-plan/ledger/PHASE_LEDGER.md`
(SEQ entries for G0-1 … G0-8) and summarised in `ledger/PROJECT_LEDGER.md`.
Classes: `unit` (`OwnerTrustPostureTests`, `OwnerGrantCoverageTests`,
`ComputerUseGuardPostureTests`, the pinned suites with ADR-064-cited
assertion updates), `live-local` (three driver turns with no confirmation
card on the stable-signed bundle), `owner-attested` (the owner's verbatim
line), and the full `scripts/aura-test.sh` loop rerun 2–3×. The lifted
computer-use guards are proven at `unit` class in PA-0; a live
computer-use leg with a `send`-class step belongs to PA-6's soak and is not
claimed here.

## Consequences

- Positive: no confirmation card for the owner on any registered capability;
  computer use runs a plan to completion instead of stopping on intent,
  focus, modal, or step count; the "registered but denied" defect class has a
  permanent test.
- Negative: the blast radius of a wrong plan or a misread utterance is now
  bounded only by the planner, the grants, identity-change detection, the
  iteration ceiling, and the owner's hand on the emergency stop. The owner
  accepted this in writing.
- Falsifiers: any record calling this posture a default; any test that
  relabels it multi-user-safe; any build that ships it beyond this Mac; any
  future change that removes the emergency stop or routes production through
  the demo auto-allow presenter.
