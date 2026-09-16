# Cross-Cutting Constraints — what binds every PA phase

These constraints are derived from `AGENTS.md`, the accepted ADRs, the pinned test suites, and the repo's project memory. A phase that violates one is not done, whatever its gates say.

---

## 1. Invariants that do not move

| Invariant | Source | Consequence for this plan |
| --- | --- | --- |
| The policy engine evaluates and audits every capability call | `AGENTS.md` "Never bypass the permission engine for convenience"; `PolicyEngine_Evaluation.swift` | Posture changes go through seeded grants + ADR (PA-0). No call path skips `PolicyEngine`; `AutoAllowConfirmationPresenter` stays demo-only |
| Security policy never changes silently | `AGENTS.md` "Never silently change architecture, security policy, data schema…" | One ADR per phase that widens capability (ADR-064…069); protocol rule A7 blocks a `[policy]` gate without an ADR citation |
| Local-only, no Developer ID, no external distribution | ADR-049, ADR-051, ADR-052 | Nothing here is release evidence; every ledger entry says so where relevant |
| Emergency stop and computer-use structural guards | ADR-019, ADR-039, ADR-055 §1 | Untouched (D-2). They are halts, not prompts |
| Screen-context sensitive-app exclusion, redaction, zero retention | ADR-018 (Phase 17) | Untouched |
| Prompt-injection classifier, network allowlist fail-closed | ADR-020, ADR-055 §6 | Untouched |
| Privilege separation across helpers | ADR-034, ADR-044 | Helpers are not merged; PA-1 minimises *prompts*, not processes |
| Ledger history is never rewritten | `AGENTS.md`; memory rule "corrections are new entries" | Plan ledger and repo ledger are append-only |
| No secrets in source, logs, fixtures, ledgers | `AGENTS.md` | Gmail client secret and VS Code secret live only in Keychain (PA-3); evidence files are redacted before commit |
| Onboarding stage machine is behavior-frozen | UI-5 / ADR-063 | PA-1, PA-2, PA-4 change stage *presentation and copy* only |
| Relative typography, tokens-first, Liquid Glass where earned | UI-0 / ADR-057 | Any new row uses `AuraDesign` tokens |
| Accessibility identifiers are API | `AuraAccessibilityIdentifiers.swift`, pinned tests | New controls get IDs; existing IDs never change |
| Real Turkish copy | F-005 class; copy-table guard | Every new string is EN+TR in `AuraCopy` |

## 2. Honesty rule for states

- "Hazır" / "Bağlı" render only when the registry or snapshot says `.ready`.
- The PA-3 **on-demand** projection is a UI reading of a *specific* disabled reason (host application not running). Its unit test enumerates the exact reason strings it may map; anything else keeps negative wording.
- No "no samples" ever renders as zero; mock-derived values stay labelled (UI plan principle 6, unchanged).

## 3. Verification contract (per phase, from `08-rollout.md` §2)

1. `./scripts/aura-test.sh` full loop: 22 targets (equal to `Package.swift` `testTarget` count on 2026-09-15 — re-check the diff each phase), rerun 2–3×, redirected to a file, `grep -c '^PASSED:'` and `grep 'Failed bundles'` captured. Never `tail` the runner.
2. New unit/integration tests for every new component and every changed default.
3. Pinned suites pass unchanged, or the change is deliberate and cited to the phase ADR.
4. Live acceptance through `scripts/sp011-acceptance/aura-drive.applescript` for every touched interactive surface, on the **stable-signed bundle** launched through LaunchServices (`open -a`), never exec'd from a shell (TCC attribution).
5. `codesign --verify --deep --strict` + `scripts/verify-signature.sh` on the bundle used for live legs.
6. ADR written; `ledger/PROJECT_LEDGER.md` appended; `ledger/CURRENT_STATE.md` atomically rewritten.
7. Commit/push only on explicit go-ahead in that turn; explicit paths; direct to `origin/main`.

## 4. Environment invariants (from project memory)

- Toolchain: macOS 27 / Swift 6.4 / Xcode 27 beta 5 (`TOOLCHAIN.md`); `swift test` is not the path — `./scripts/aura-test.sh` is.
- iCloud-synced paths break codesign — build under `~/Library/Developer/AURA/…` or `$TMPDIR`, as the UI plan's deliveries did.
- Installed app ≠ your build: every live leg names the bundle path and its main-executable SHA-256.
- Dock/TCC caches: use a fresh bundle path when identity or icon changes are under test.
- Per-executable TCC: list which executable a permission belongs to in every permission-related ledger entry.

## 5. Scope guards

Each prompt carries an allowed-files list. Edits outside it are defects even if harmless. Cross-phase dependencies are explicit:

- PA-0 → everything (no challenge may be presented once PA-0 lands).
- PA-1 → PA-2 (login-item launch must not re-prompt), PA-3 (Calendar/Contacts grants), PA-4 (Speech Recognition grant), PA-5 (indicators).
- PA-3 → PA-5 (integration rows on the Privacy tab).
- PA-4 is independent of PA-3 and may be reordered before it if the owner prefers voice first (see `08-rollout.md` §1).

## 6. What "kusursuz" means here

A phase is flawless when (a) its gates carry evidence of the class the prompt names, (b) the owner's own attestation lines exist for what only the owner can see, (c) a "double check" pass — fresh build, full suite rerun, source re-read against the phase's design doc bullet by bullet — finds nothing. The double check is a real audit, not a summary; it has found real gaps in this repository twice before (Phase 16 ordering bug; Phase 17 region scoping).
