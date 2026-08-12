# H-009 Bounded Context Summary and Source Map

**Status:** Authored derived pointer; not a source of truth
**Snapshot:** 2026-08-10T14:28:11Z
**Program:** `AURA-REPO-HYGIENE`
**Live repository:** `main`, `HEAD == origin/main == 6e53e6a941756e4b34f24f5de3c9c29bdc8147bf`, relation `0/0`, clean worktree, 70,094 ignored paths

This document is a bounded successor summary for a fresh session. It reduces
context loading without rewriting any append-only ledger. Every current claim
below points to the authoritative file that owns it. If this summary conflicts
with an authority, the authority wins and this pointer is stale.

## Source-of-truth map

| Fact class | Authoritative source | Use in a fresh session |
|---|---|---|
| Active prompt, ordered completion, blocked state, live hygiene Git fields | `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json` | Read first; do not infer the next prompt from prose |
| Prompt order and dependency | `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_PROMPT_MANIFEST.json` | Confirm the active prompt and its predecessor |
| Human gap definition and roadmap | `docs/operations/REPO_HYGIENE_PROGRAM.md` | Read only the matching `HYGIENE-*` section |
| Hygiene evidence history | `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md` | Read the latest matching evidence entries; history is append-only |
| Evidence ID existence and cross-program projection | `AURA_RUNTIME_COMPLETION/state/EVIDENCE_INDEX.md` | Verify every evidence ID before claiming a gate |
| Risk status, owner, and residual disposition | `AURA_RUNTIME_COMPLETION/state/RISK_REGISTER.md` | Read matching `RISK-REPO-HYGIENE-*` rows |
| Runtime/product verified content baseline | `AURA_RUNTIME_COMPLETION/state/current-state.json` | `repository.verified_head` remains the audited content baseline under ADR-045 |
| Capability binding | `AURA_RUNTIME_COMPLETION/state/capability-matrix.json` | Must match the verified content baseline unless product code is re-audited |
| Next-session handoff and bounded file/evidence arrays | `AURA_RUNTIME_COMPLETION/context/session-handoff.json` | Use as the concise handoff after Tier-0 reads |
| Architecture and security boundaries | `docs/architecture/02_ARCHITECTURE.md`, relevant ADRs, and `H-009_ARCHITECTURE_AUDIT.md` | Treat ADR status and evidence limits as binding |

The live hygiene repository head is `6e53e6a…`. The runtime verified content
baseline is `47775180c224f87fa5a58703f793515ffcb2c35c` because the descendants
after that merge are projection-only commits. This is the ADR-045 distinction
between the live repository tip and the last audited product/content baseline;
it is not permission to treat an unaudited source change as verified.

## Bounded loading order

Tier 0 is the required order in
`AURA_RUNTIME_COMPLETION/context/REPO_HYGIENE_READ_FIRST.md`:

1. `AGENTS.md`
2. `README.md`
3. `ledger/CURRENT_STATE.md`
4. the current/relevant `ledger/PROJECT_LEDGER.md` slice
5. `REPO_HYGIENE_READ_FIRST.md`
6. `REPO_HYGIENE_CONTROL_CONTRACT.md`
7. `REPO_HYGIENE_STATE.json`
8. `REPO_HYGIENE_PROMPT_MANIFEST.json`
9. the active `HYGIENE-*` program section
10. only the active prompt file

For H-009, Tier 1 adds the focused hygiene ledger tail, matching evidence and
risk rows, `ACTIVE_CONTEXT.md`, `session-handoff.json`, `Package.swift`, the
SwiftPM graph, and the architecture ADRs named in the audit. Do not load the
entire historical project ledger unless a cited evidence entry is missing.

## Measured context gap

The pre-remediation projection sizes were:

| File | Lines | Bytes | Interpretation |
|---|---:|---:|---|
| `ledger/PROJECT_LEDGER.md` | 3,753 | 543,873 | Append-only historical source; never rewrite |
| `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md` | 1,067 | 187,158 | Append-only runtime projection |
| `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md` | 447 | 127,598 | Focused append-only evidence history |
| `AURA_RUNTIME_COMPLETION/context/ACTIVE_CONTEXT.md` | 373 | 22,712 | Bounded active context, but stale H-008 claims before H-009 sync |
| `AURA_RUNTIME_COMPLETION/context/session-handoff.json` | 513 | 33,284 | Bounded handoff with bounded evidence/file arrays |
| `AURA_RUNTIME_COMPLETION/state/EVIDENCE_INDEX.md` | 154 | 97,919 | Cross-program evidence index |
| `AURA_RUNTIME_COMPLETION/state/RISK_REGISTER.md` | 79 | 36,318 | Cross-program risk projection |

Before the H-009 synchronization, seven active projections still stated that
H-008 was ready and eight still stated that H-009 was unopened. The focused
hygiene ledger also contained one exact duplicate H-008 quarantine heading.
The duplicate is retained as historical evidence; the latest H-009 pointer is
the active interpretation. Historical stale wording is not current state when
it is superseded by the newest evidence-backed projection entry.

## Fresh-session acceptance check

A new session can recover the active hygiene truth by reading this pointer
after the required Tier-0 files, then checking:

- `REPO_HYGIENE_STATE.json` for the active prompt and state;
- the latest `EV-REPO-HYGIENE-H-009-*` entry for evidence and the six-question gate;
- the matching evidence/risk rows and `session-handoff.json` for projection limits;
- `H-009_ARCHITECTURE_AUDIT.md` for the architecture boundary conclusion.

This summary does not close product, release, beta, CI-hosted, full-Xcode,
historical-secret, or original-Git-object-database gates. H-010 remains a
separate explicit next-prompt boundary and is not opened by this summary.

## H-010 final local-gate pointer — 2026-08-12T11:28:10Z

The latest H-010 evidence supersedes the earlier blocked local-lint/coverage
snapshot: feature commit `de320a05ba9195b982e887e13c2116ba3698bc8a` passes
strict SwiftLint with zero violations in 1,066 files, the unchanged canonical
wrapper with 21/21 bundles, 795 tests, and 70.57% coverage, plus formatter,
build, full tests, and fsck. In-repository untracked count is zero. The 219
byte-identical copy artifacts are preserved in recoverable external quarantine
`/Users/m_ras/Desktop/AURA-H010-QUARANTINE-20260812`. Feature push is complete;
no-ff merge/main push and exact final hosted-CI observation remain pending.
Read `REPO_HYGIENE_STATE.json` and the latest focused-ledger entry before
declaring H-010 complete. No H-011 exists.

The feature was merged no-ff and pushed to `main` at
`d0527d923d2ed02be3daf291e8181c900508a59a`; the state projections now point
to this synchronized main SHA. Hosted run `31592649228` remained queued with
no completed steps, so the final hosted result is still open.
