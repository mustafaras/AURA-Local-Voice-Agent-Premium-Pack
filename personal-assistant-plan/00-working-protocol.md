# PA Plan — Anti-Amnesia Working Protocol

**Status:** Binding execution contract for every phase of this plan. It defines the anti-amnesia machinery, the prompt↔ledger mutual-audit contract, and the transition gates with mandatory owner approval. It is the `UI-` plan's protocol (`docs/archive/ui-improvement-plan/00-working-protocol.md`) carried forward under the `PA-` prefix with two additions: a **policy-change gate** (§4 A7) and a **live-evidence class rule** (§6).

---

## 1. Why this exists

Implementation spans many sessions; sessions get compacted; the single most dangerous failure mode is *drift* — a phase declared done that is not done, a security posture changed without an ADR, or a transition that happened without approval. This machinery makes state live **in the repo, not in the conversation**, and makes lying mechanically detectable.

## 2. The file machine

```text
personal-assistant-plan/
├── 00-working-protocol.md        ← this contract (the rules)
├── 01…08-*.md                    ← design docs (evidence + design per axis, rollout)
├── prompts/
│   ├── PA-0.prompt.md            ← one prompt per phase, frozen at phase start
│   ├── PA-1.prompt.md … PA-6.prompt.md
├── ledger/
│   ├── CURRENT_PHASE.md          ← volatile state — atomic rewrite, ONE source of "where are we"
│   └── PHASE_LEDGER.md           ← append-only — every gate event, every approval
├── evidence/                     ← captured command outputs / screenshots cited by SEQ entries
└── validate-continuity.sh        ← mechanical cross-audit (the referee)
```

Roles: the **prompt** declares what "done" means (gate IDs). The **ledger** records what actually happened (evidence). The **validator** proves the two agree. No file in the machine trusts any other file's prose — only its parseable line format.

## 3. Line formats (the parseable contract)

**`ledger/CURRENT_PHASE.md`:**

```text
updated: <ISO-8601 timestamp>
active_phase: PA-N
phase_status: pending | in-progress | awaiting-approval | completed
next_phase: PA-(N+1) | none
last_seq: <integer — must equal the highest SEQ in PHASE_LEDGER.md>

## Gates (mirror of prompts/PA-N.prompt.md §Gates — must match 1:1)
| Gate | Description | Status | Evidence |
| --- | --- | --- | --- |
| GN-1 | <description> | pending | — |
```

Gate statuses: `pending`, `in-progress`, `passed`, `blocked`. Nothing else.

**`ledger/PHASE_LEDGER.md` — append-only entries:**

```text
## SEQ-0013 — <ISO timestamp> — PA-0 — GN-k PASSED
- evidence: <file:line, command output snippet, or evidence/ path>
- verified: <exact command run>
```

**Approval lines (the only legal transition record):**

```text
APPROVAL: PLAN -> PA-0 — user token: "ONAY PA-0" — <date> — <one-line scope confirmation>
APPROVAL: PA-0 -> PA-1 — user token: "ONAY PA-1" — <date> — <one-line scope confirmation>
```

The first form opens the plan (the validator requires it before any `PA-0` entry); the second form is the only legal record for every later transition.

**Decision lines (owner decisions D-1…D-6 from README §7, recorded once):**

```text
DECISION: D-3 — owner: "<verbatim>" — <date> — <resolved value>
```

## 4. The mutual-audit contract (bidirectional, mechanically enforced)

| # | Rule | Enforced by |
| --- | --- | --- |
| A1 | Prompt → Ledger: **every** gate ID in the active prompt appears in `CURRENT_PHASE.md` with a status. | validator check 3 |
| A2 | Ledger → Prompt: ledger gate rows cite only gate IDs that exist in the active prompt. | validator check 3 |
| A3 | `active_phase` names an existing `prompts/PA-N.prompt.md`. | validator check 2 |
| A4 | `last_seq` equals the highest `SEQ-` in `PHASE_LEDGER.md`. | validator check 4 |
| A5 | Phase `PA-(N+1)`'s first ledger SEQ appears **after** an `APPROVAL: PA-N -> PA-(N+1)` line. | validator check 5 |
| A6 | Approval is a **user token**, never inferred: the literal `ONAY PA-N` (or an explicit English equivalent) typed by the owner. | protocol + validator check 5 |
| A7 | **Policy-change gate:** any phase that changes a `confirmationRequirement`, a seeded grant, `denyByDefaultTiers`, a TCC request path, a Keychain service name, or a default that widens capability must cite an ADR number in the gate's evidence before the gate can be `passed`. | validator check 6 (ADR reference present in the ledger entry for gates tagged `[policy]` in the prompt) |

**The iron rule:** *one phase, fully and perfectly applied, before the next is even read.* `next_phase`'s prompt may be written in advance but is frozen until approval opens it.

## 5. Session protocol (the anti-amnesia loop)

**Start of every session (mandatory, in order):**

1. Read `ledger/CURRENT_PHASE.md` fresh.
2. Read the tail of `ledger/PHASE_LEDGER.md` (last ~40 lines).
3. Read the active phase's prompt file.
4. Read the phase's design doc(s) (cited by the prompt).
5. Run `bash validate-continuity.sh` — if it fails, **fix the machine before touching any code.**
6. Run the repo startup sequence (`AGENTS.md`): `ledger/CURRENT_STATE.md`, `ledger/PROJECT_LEDGER.md` tail.
7. State aloud (in the visible reply): active phase, completed gates, next gate, blocked items, open owner decisions. Then work.

**During work — checkpoint discipline:**

- The moment a gate's verification passes, append its SEQ entry and rewrite `CURRENT_PHASE.md` (status + `last_seq` + `updated`). State never lives only in the conversation.
- One gate at a time; no gate batched with another's verification.
- `phase_status: awaiting-approval` + the question *"Faz PA-N tamamlandı; geçiş için onayınız?"* is the mandatory end-of-phase turn. The assistant never writes an APPROVAL line on its own, never starts the next phase, never treats silence as approval.
- Commit/push only on an explicit go-ahead in that turn; staged by explicit file path; direct to `origin/main` (this repo has no PR workflow).

**End of every session:** `CURRENT_PHASE.md` must be true at exit.

## 6. Evidence classes (what a `PASSED` row may cite)

| Class | Meaning | Example |
| --- | --- | --- |
| `unit` | deterministic test in a test target | `AuraPolicyTests` green, N tests |
| `integration` | `AURAIntegrationTests` or cross-module test | view-construction test |
| `live-local` | the stable-signed bundle on this Mac, driven by the AppleScript driver or observed by command output | `osascript … status` → `OK AURA durumu: Boşta` |
| `os-observed` | macOS state read read-only | `codesign -dvv`, `sfltool dumpbtm`, `log show --predicate 'subsystem == "com.apple.TCC"'` |
| `owner-attested` | a fact only the owner can observe (a prompt did/did not appear on screen) — recorded with the owner's verbatim words | "hiç izin sorusu çıkmadı" |

A gate whose verification column names `live-local` or `os-observed` may not be passed with `unit` evidence alone. "Should pass" is `in-progress`, never `passed`. No synthetic evidence is relabeled as live, signed, notarized, beta, or production (ADR-053 falsifiers apply).

## 7. Validator usage

```bash
bash personal-assistant-plan/validate-continuity.sh
```

Exit 0 = machine coherent. Non-zero = **stop and repair** before any other action. Run at session start, after every gate checkpoint, and before any transition turn.

## 8. Relationship to repo governance

This machine wraps, and never replaces, the repo's discipline: ADR per phase (`docs/decisions/ADR-NNN-*.md` per template; next free number is ADR-064), `ledger/PROJECT_LEDGER.md` append (full bolded-field structure), atomic `ledger/CURRENT_STATE.md` rewrite, pinned-test discipline, full `./scripts/aura-test.sh` loop rerun 2–3× (redirect to a file; `grep -c '^PASSED:'`, `grep 'Failed bundles'`; never `tail`). The plan-local ledger is the *execution* record; the repo ledger is the *institutional* record.
