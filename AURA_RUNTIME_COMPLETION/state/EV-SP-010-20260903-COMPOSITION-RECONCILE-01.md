# EV-SP-010-20260903-COMPOSITION-RECONCILE-01

- **Evidence ID:** `EV-SP-010-20260903-COMPOSITION-RECONCILE-01`
- **Reconciles / supersedes-in-traceability:** `EV-SP-010-20260817-COMPOSITION-01`
- **Evidence class:** product source / build / test / state — reconciliation of an underspecified historical index row.
- **Timestamp:** 2026-09-03
- **Prompt / gap:** SP-010 — Provider, Account, and UI Composition (deterministic slice of `OPEN-06`).
- **Session:** AURA-SP-010-EVIDENCE-RECONCILE-20260903
- **Repository:** `main`; `HEAD == origin/main == 44f41c7986445526fd3f40f36c5a3972d26f65ea`.
- **Environment:** macOS 27.0 arm64; Apple Swift 6.4; Python 3.14.6; Git 2.54.0.

## Purpose (honest scope)

`EVIDENCE_INDEX.md` row for `EV-SP-010-20260817-COMPOSITION-01` (line 78) was
recorded on 2026-08-17 with **empty artifact/hash cells** and a commit value of
`Working tree (SP-010 uncommitted)`, because SP-010 was closed by *reconciling
an already-advanced machine state* rather than producing a fresh artifact file.
The implementation itself was committed subsequently (bundled into the
`feat(sp-011)` series). This record closes that traceability gap by pinning the
SP-010 source/test artifacts to the current committed tree and their SHA-256
hashes. It does **not** claim live provider OAuth, real-account configuration,
TCC/Contacts/Calendar prompts, real Safari native-messaging, mutation/send, or
user-present acceptance — those remain explicitly out of SP-010's deterministic
slice and are owned by SP-011 (see limitations).

## Procedure

1. Re-read the SP-010 prompt file, its ledger entry
   (`SECOND_PASS_LEDGER.md`, 2026-08-17T16:59:23Z), and the `EVIDENCE_INDEX.md`
   row 78.
2. Located the SP-010 source and test files in the working tree and confirmed
   each is tracked (`git ls-files`) and present at `HEAD`.
3. Recorded the enclosing commit (`44f41c7`) and each file's SHA-256.
4. Re-checked the deterministic boundary claim against the passing SP-010 test
   suite (documented in the 2026-08-17 ledger entry and the SP-010 test files).

## Artifacts pinned (all present and tracked at `HEAD`)

| File | SHA-256 |
|---|---|
| `Sources/AuraProductivity/ProductivityAdapters_IntegrationOnboardingService.swift` | `fb46336ea7dc7313e30f60fc39e6a68487c1f5130ee0014a586ab08fc318b711` |
| `Tests/AuraProductivityTests/SP010ProviderAccountTests.swift` | `f2a7310a12a2358ac14687e72af177ca58782b09b27ae1f52b8c03464e639624` |
| `Tests/AuraIntentTests/SP010ProductivityRoutingTests.swift` | `7bb6bc34824620a7d69783125727deab1d9be3a99591c8cb9e6ff88f883c4552` |
| `Tests/AURAIntegrationTests/SP010ProductivityCompositionTests.swift` | `ea6334eb7e4b1d5933237963d0680d3c68b75e33d95f4caba37343ba79560187` |
| `AURA_RUNTIME_COMPLETION/prompts/second_pass/SP-010_PROVIDER_ACCOUNT_AND_UI_COMPOSITION.prompt.md` | `c2d7dfa4c6f341fc162c832bab31dc2eaf2d208cad8932915702aff09f966d31` |

The SP-010 test files above contain 66 Swift Testing `@Test` annotations
(26 `AuraProductivityTests` / 20 `AuraIntentTests` / 20 `AURAIntegrationTests`),
matching the 48+ focused test claim. The implementation (integration onboarding
with `.read-only` tier + Keychain account records, bounded HTTP/Gmail transport,
`ProductivityRuntime` composition root, redacting `ProductivityReadBridge`,
registry/routing, and actionable UI rows with revocation) conforms to the
SP-010 mission and hard boundaries.

## Result / verdict

**Passed** at the deterministic boundary. SP-010 is `completed` for the
deterministic slice of `OPEN-06`. Artifacts are committed and hash-pinned above.

## Limitations

- Does **not** exercise live provider OAuth consent, real account configuration,
  TCC/Contacts/Calendar prompts, real Safari native-messaging, mutation/send, or
  user-present acceptance. Four capabilities remain `.disabled`.
- Commit `44f41c7` is the current pointer-sync `HEAD`; the SP-010 artifacts were
  introduced with the `feat(sp-011)` series (`1d7f191` and descendants). The
  hash above reflects their state at the time of this reconciliation.
