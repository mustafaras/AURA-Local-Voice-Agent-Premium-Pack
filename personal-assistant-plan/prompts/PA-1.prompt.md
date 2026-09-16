---
id: PA-1
sequence: 1
track: PA
depends_on: PA-0
next_prompt: PA-2
state: pending
design_docs: 02-one-identity-one-consent, 07-cross-cutting-constraints
adr: ADR-065
---

# PA-1 — One Identity, One Consent (no macOS re-prompt, no Keychain password)

## Mission

Make every executable in the bundle carry the stable local identity, keep development builds out of the production Keychain namespace, and collect every macOS permission — Microphone, Speech Recognition, Accessibility, Screen Recording, Calendars, Contacts — once, in one guided pass, so that relaunch and rebuild never re-prompt.

## Read before acting

- Plan: `ledger/CURRENT_PHASE.md`, ledger tail, `00-working-protocol.md` §3–§6, `02-one-identity-one-consent.md`, `07-cross-cutting-constraints.md` §4
- Repo: `docs/decisions/ADR-030-stable-local-signing-natural-system-tts.md`, ADR-034, ADR-044, `scripts/sp011-acceptance/README.md` (TCC attribution note)
- Code: `scripts/codesign-adhoc.sh`, `scripts/verify-signature.sh`, `scripts/build-app-bundle.sh:55-100`, `Resources/*-Info.plist`, `Sources/AURA/PermissionCoordinator.swift`, `Sources/AuraCore/Configuration_AppConfiguration.swift`, `Sources/AuraSecurity/SecretStoring.swift`, `Sources/AuraProductivity/ProductivityTypes_AuthorizationProbe.swift`, `Sources/AURA/AuraMenuView.swift` (onboarding `privilegedAccess` stage), `AuraMenuView_Tabs.swift:355-401,556-566`
- Map first (G1-0): which process hosts each AX/screen call — `Sources/AuraAutomation/AccessibilityObserver.swift`, `Sources/AuraComputerUse/UIActionExecuting.swift`, `ModalDialogDetecting.swift`, `Sources/AuraScreen/AccessibilitySecureFieldDetector.swift`.
- Owner decision D-6 recorded.

## Hard boundaries

- **Allowed files:** `scripts/codesign-adhoc.sh`, `scripts/verify-signature.sh`, `Sources/AuraSecurity/CodeIdentityProbe.swift` (new), `Sources/AuraCore/Configuration_AppConfiguration.swift` (service-name derivation seam only), the composition line that passes the derived service name, `Sources/AURA/PermissionCoordinator.swift`, `Sources/AURA/AuraMenuView.swift` (privileged-access stage presentation), `AuraMenuView_Tabs.swift` (indicator rows), `ProductUIState.swift` (copy keys), `AuraAccessibilityIdentifiers.swift` (additions), tests, `docs/decisions/ADR-065-*.md`, repo ledgers, plan ledger.
- Forbidden: writing to the TCC database, clearing the installed app's consent records with system tools, merging helpers, changing bundle identifiers, changing the onboarding stage machine, requesting Full Disk Access.
- Never exec the app from a shell for a live leg; always `open -a`.

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G1-0 | Process→permission map: which executable needs Accessibility / Screen Recording / Microphone / Speech / Calendars / Contacts, with file:line for each call site | table in ledger; `evidence/PA-1/permission-map.md` |
| G1-1 | `[policy]` Identity invariant: ad-hoc fallback opt-in only; `verify-signature.sh` checks every nested executable's designated requirement; negative test (ad-hoc copy) fails; `evidence/PA-1/identity-inventory.txt` recorded incl. certificate `notAfter` | `os-observed`: `codesign -d -r-` per executable; script exit codes |
| G1-2 | `[policy]` Keychain isolation: non-stable-signed runs derive `<serviceName>.dev`; unit tests for stable / ad-hoc / unsigned; a debug-binary launch leaves the production items untouched and shows no dialog | `unit` + `live-local` (`security find-generic-password -s …` counts, redacted) + `owner-attested` |
| G1-3 | Single consent pass: `PermissionSnapshot` has six fields; the `privilegedAccess` stage requests all six in order with live rows and Settings fallbacks; Privacy/Recovery tabs render the two new rows; copy EN/TR | `integration` view tests; copy guard; a11y IDs pinned |
| G1-4 | Persistence: fresh install → one pass → relaunch ×3 → rebuild+reinstall → relaunch: zero dialogs; all six indicators `Verildi`; TCC log excerpt captured (or the observation that it is withheld) | `live-local` driver labels + `os-observed` + `owner-attested` |
| G1-5 | Full verification + governance: suite ×2–3, ADR-065, repo ledgers, `CURRENT_STATE` | outputs under `evidence/PA-1/` |
| G1-6 | Machine coherence: validator OK, all gates `passed`, `awaiting-approval` | `bash validate-continuity.sh` |

## Per-gate procedure

- **G1-0:** grep + read; produce the map; decide whether the automation helper needs its own Accessibility grant. Record the decision with evidence.
- **G1-1:** edit the two scripts; sign a bundle to a fresh path; run the verifier; ad-hoc sign a copy in `$TMPDIR` and confirm failure; `security find-certificate -c "AURA Stable Local Signing" -p | openssl x509 -noout -enddate` for `notAfter`.
- **G1-2:** implement `CodeIdentityProbe` with `SecStaticCodeCreateWithPath` + `SecStaticCodeCheckValidity` against the stable requirement (verify API names with a `swiftc -typecheck` probe first); wire the derived service name; tests; live check.
- **G1-3:** extend snapshot and stage presentation; copy keys; IDs; tests.
- **G1-4:** the persistence protocol from `02-…md` §6, in order, each step's output captured; owner's words quoted verbatim.
- **G1-5/G1-6:** standard closing sequence.

## Evidence template

```text
## SEQ-00NN — <ISO> — PA-1 — G1-k PASSED
- evidence: …
- verified: …
- adr: ADR-065   ← for [policy] gates
- executable: <bundle id or path>   ← for every permission-related entry
```

## Risks / reverting

If the stable identity is missing on the machine, stop: provisioning it is an owner action (ADR-030 §Decision 1). If macOS re-prompts after a rebuild despite a stable DR, capture `codesign -dvv` before/after and treat as `blocked` with the diff — never "fix" it by clearing macOS's own consent records.

## Session script

Protocol §5, then G1-0 → G1-6. End with `awaiting-approval` and the transition question.

## Cognitive completion gate

(1) Which executables does macOS see, and which of them prompted, exactly once? (2) What proves a `swift build` binary can no longer trigger the Keychain dialog? (3) Which permission will macOS still be allowed to ask about again, and where is that documented?
