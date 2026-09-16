---
id: PA-6
sequence: 6
track: PA
depends_on: PA-5
next_prompt: none
state: pending
design_docs: 08-rollout (§6), 07-cross-cutting-constraints
adr: none (closure record in ledgers; ADR set ADR-064…ADR-069 must be Accepted)
---

# PA-6 — Always-On Soak & Program Closure (plan exit)

## Mission

Prove the *program*, not a phase: from a clean reinstall, one consent pass, a real login, "Hey AURA", and a day of use with zero dialogs and zero confirmation cards — then close the plan. This is the plan's final phase; its close is a **plan-completion turn**.

## Read before acting

- Plan: `ledger/CURRENT_PHASE.md`, ledger tail, `00-working-protocol.md`, `08-rollout.md` §6, `07-cross-cutting-constraints.md` §6
- Repo: `ledger/CURRENT_STATE.md`, ADR-064…ADR-069, `scripts/verify-signature.sh`, `scripts/build-release-artifact.sh`
- Owner authorization for **install to `/Applications`** must be explicit in the turn that installs.

## Hard boundaries

- **Allowed files:** ledgers, `CURRENT_STATE.md`, `evidence/PA-6/`, `personal-assistant-plan/README.md` status line, a `CLOSED.md`-style closure section in this plan's README. **No source changes** — a defect found here reopens the owning phase by owner decision, never by an edit inside PA-6.
- No release, notarization, Developer ID, beta/RC, or external-publication claim (ADR-049).

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G6-1 | Clean reinstall: prior app moved to rollback path; PA-5 bundle built, stable-signed, `verify-signature.sh` OK, installed; SHA-256 recorded; identity inventory diff vs. PA-1 empty | `os-observed` + `live-local` |
| G6-2 | First launch → guided setup → one consent pass; owner records how many dialogs and which | `owner-attested` |
| G6-3 | Logout → login → AURA running, Boşta, wake armed, no onboarding, no dialog | `os-observed` + `live-local` + `owner-attested` |
| G6-4 | Voice + tasks: "Hey AURA, saat kaç" answered; shell, coding-agent, app-terminate, computer-use mutation turns with zero cards; Calendar/mail/Chrome/VS Code reads; memory correct/delete/conflict | `live-local` transcripts |
| G6-5 | 24 h soak: zero dialogs, zero cards, Gmail token refresh observed, CPU/energy numbers, certificate `notAfter` re-checked | `owner-attested` + `os-observed` |
| G6-6 | Governance closure: ADR-064…069 Accepted; `PROJECT_LEDGER` closure append; `CURRENT_STATE` atomic rewrite; falsifier review; plan README status → CLOSED | `evidence/PA-6/` |
| G6-7 | Machine coherence + plan completion: validator OK, all gates `passed`, `phase_status: completed`, `next_phase: none` | validator |

## Per-gate procedure

Follow `08-rollout.md` §6 row by row. Every owner attestation is quoted verbatim with a timestamp. Any failure → record `blocked`, name the owning phase, stop.

## Evidence template

```text
## SEQ-00NN — <ISO> — PA-6 — G6-k PASSED
- evidence: …
- verified: …
- bundle: /Applications/AURA.app sha256=<main executable>
```

## Session script

Protocol §5, then G6-1 → G6-7. End with `phase_status: completed` and the plan-completion statement; ask whether the owner wants the archive step (`docs/archive/personal-assistant-plan/`) — do not perform it without the token.

## Cognitive completion gate

(1) Over 24 h, what asked the owner for anything, and why was it allowed to? (2) Which capability is not `Hazır`/`Bağlı`, and is that honest? (3) What would falsify ADR-064 tomorrow?
