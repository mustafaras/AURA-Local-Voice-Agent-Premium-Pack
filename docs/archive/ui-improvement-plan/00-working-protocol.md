# UI Plan — Anti-Amnesia Working Protocol (Volume III)

**Status:** Binding execution contract for every phase of this plan. It defines the anti-amnesia machinery, the prompt↔ledger mutual-audit contract, the transition gates with mandatory user approval, and the model-specific tactics for the session model (GLM 5.3 Flash).
**Volume:** III — Execution machinery (this file, `prompts/`, `ledger/`, `validate-continuity.sh`).

---

## 1. Why this exists

The plan's implementation will span many sessions. Sessions get compacted; context summaries lose detail; the single most dangerous failure mode is *drift*: a phase declared done that is not done, or a transition that happened without approval. This machinery makes the state live **in the repo, not in the conversation**, and makes lying mechanically detectable.

## 2. The file machine

```text
ui-improvement-plan/
├── 00-working-protocol.md        ← this contract (the rules)
├── prompts/
│   ├── UI-0.prompt.md            ← one prompt per phase, frozen at phase start
│   ├── UI-1.prompt.md … UI-5.prompt.md
├── ledger/
│   ├── CURRENT_PHASE.md          ← volatile state — atomic rewrite, ONE source of "where are we"
│   └── PHASE_LEDGER.md           ← append-only — every gate event, every approval
└── validate-continuity.sh        ← mechanical cross-audit (the referee)
```

Roles: the **prompt** declares what "done" means (gate IDs). The **ledger** records what actually happened (evidence). The **validator** proves the two agree. No file in the machine trusts any other file's prose — only its parseable line format.

## 3. Line formats (the parseable contract)

These exact formats are what `validate-continuity.sh` parses. Any other prose in these files is decoration the referee ignores.

**`ledger/CURRENT_PHASE.md`:**

```text
updated: <ISO-8601 timestamp>
active_phase: UI-N
phase_status: pending | in-progress | awaiting-approval | completed
next_phase: UI-(N+1)
last_seq: <integer — must equal the highest SEQ in PHASE_LEDGER.md>

## Gates (mirror of prompts/UI-N.prompt.md §Gates — must match 1:1)
| Gate | Description | Status | Evidence |
| --- | --- | --- | --- |
| GN-1 | <description> | pending | — |
```

Gate statuses: `pending`, `in-progress`, `passed`, `blocked`. Nothing else.

**`ledger/PHASE_LEDGER.md` — append-only entries:**

```text
## SEQ-0013 — <ISO timestamp> — UI-0 — GN-k PASSED
- evidence: <file:line, command output snippet, or screenshot path>
- verified: <exact command run>
```

**Approval lines (the only legal transition record):**

```text
APPROVAL: UI-0 -> UI-1 — user token: "ONAY UI-1" — <date> — <one-line scope confirmation>
```

## 4. The mutual-audit contract (bidirectional, mechanically enforced)

| # | Rule | Enforced by |
| --- | --- | --- |
| A1 | Prompt → Ledger: **every** gate ID defined in the active phase's prompt must appear in `CURRENT_PHASE.md` with a status. A gate without a ledger row is an unimplemented requirement, never a transition. | validator check 3 |
| A2 | Ledger → Prompt: ledger gate rows may cite only gate IDs that exist in the active prompt. An invented gate ID is a defect. | validator check 3 (parity, both directions) |
| A3 | CURRENT_PHASE → Prompt: `active_phase` must name an existing `prompts/UI-N.prompt.md`. | validator check 2 |
| A4 | Sequence integrity: `last_seq` in CURRENT_PHASE must equal the highest `SEQ-` number in PHASE_LEDGER. A stale CURRENT_PHASE is detectable drift. | validator check 4 |
| A5 | Transition legality: phase `UI-(N+1)`'s first ledger SEQ must appear **after** an `APPROVAL: UI-N -> UI-(N+1)` line for phase N. No approval, no next phase — even if every gate says passed. | validator check 5 |
| A6 | Approval is a **user token**, never inferred: the literal string `ONAY UI-N` (or explicit English equivalent) typed by the user in the conversation is the only thing that may be quoted into an APPROVAL line. | protocol (human check) + validator check 5 |

**The iron rule:** *one phase, fully and perfectly applied, before the next is even read.* `next_phase`'s prompt file may be written in advance, but its content is **frozen** (read-only) until approval opens it; during a phase, only that phase's prompt and its gates are in scope.

## 5. Session protocol (the anti-amnesia loop)

**Start of every session (mandatory, in order):**

1. Read `ledger/CURRENT_PHASE.md` fresh.
2. Read the tail of `ledger/PHASE_LEDGER.md` (last ~40 lines).
3. Read the active phase's prompt file.
4. Read the phase's design docs (cited by the prompt).
5. Run `bash validate-continuity.sh` — if it fails, **fix the machine before touching any code.**
6. State aloud (in the visible reply): active phase, completed gates, next gate, and any blocked item. Then work.

**During work — checkpoint discipline:**

- The moment a gate's verification command passes, **immediately** append its SEQ entry to PHASE_LEDGER and rewrite CURRENT_PHASE (status + last_seq + `updated`). State never lives only in the conversation.
- One gate at a time; no gate batched with another's verification.
- `phase_status: awaiting-approval` + the question *"Faz UI-N tamamlandı; geçiş için onayınız?"* is the mandatory end-of-phase turn. The assistant never writes an APPROVAL line on its own, never starts the next phase's work, and never treats silence as approval.

**End of every session:** CURRENT_PHASE must be true at exit — if it is not, the last act of the session is rewriting it. An unrecorded gate is a lost gate after compaction.

## 6. Supercharge profile — tuned to GLM 5.3 Flash (the session model)

The protocol exploits the model's strengths and fences its failure modes:

**Strengths, used deliberately:**

- **Parallel tool calls.** Batch every independent read (CURRENT_PHASE + ledger tail + prompt + design doc) in one turn; batch independent file edits. Never serialize what can be parallel — this model's advantage is throughput.
- **Large context.** A full phase's files fit comfortably; re-reads after compaction are cheap and mandatory rather than avoided.
- **Fast iteration.** Per-gate verify-fix loops are cheap; run the failing check alone mid-phase, the full `aura-test.sh` loop only at gate G-N-final.

**Failure modes, fenced by protocol:**

- *Compaction amnesia* → the entire §5 loop: state in repo, not in conversation; `validate-continuity.sh` as the first act of every resumed session.
- *Long-task drift* (quality decay on long multi-step work) → one gate per checkpoint; the visible restatement of "active phase / completed / next gate" at every session start and after every compaction summary.
- *Overconfidence* → **no ledger write without evidence**: every `PASSED` row must cite the exact command and its output (grep lines, pass counts); "should pass" is `in-progress`, never `passed`. The ledger's rule: *claims need file:line or command output; nothing else counts as evidence.*
- *Scope creep across phases* → §4 iron rule; edits to files outside the active prompt's scope list are defects even if harmless.
- *Hallucinated file state* → every "file X exists/changed" claim in a ledger entry carries the command that proved it (`ls`, `grep -n`, `git status --short`).

**Environment invariants (from project memory, apply to every phase):** tests only via `./scripts/aura-test.sh` (rerun bundles 2–3×, grep output, never `tail`); fresh bundle path for Dock-related checks; no commit/push without explicit go-ahead in the turn.

## 7. Validator usage

```bash
bash ui-improvement-plan/validate-continuity.sh
```

Exit 0 = machine coherent. Exit non-zero = **stop and repair the ledger/prompt mismatch before any other action.** Run it at session start, after every gate checkpoint, and before any transition turn.

## 8. Relationship to repo governance

This machine does not replace the repo's phase-gate discipline — it *wraps* it. The repo-level obligations (ADR per phase, `ledger/PROJECT_LEDGER.md` append, atomic `ledger/CURRENT_STATE.md` rewrite, pinned-test discipline) remain binding and are themselves gates inside each phase prompt (the final gate of every phase). The `ui-improvement-plan/ledger/` files are the *plan-local* execution state; the repo ledger files remain the *institutional* record.
