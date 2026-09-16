---
id: PA-5
sequence: 5
track: PA
depends_on: PA-4
next_prompt: PA-6
state: pending
design_docs: 06-privacy-memory-center, 07-cross-cutting-constraints
adr: ADR-069
---

# PA-5 — Privacy & Memory Center Correctness

## Mission

Fix the memory-correction sheet defect, give every memory control an accessibility identifier, migrate the Privacy/Models tabs' English literals into `AuraCopy`, apply the D-5 relabel, and prove every memory operation end-to-end through the driver — then confirm, from this tab, that PA-1 and PA-3 left no negative indicator.

## Read before acting

- Plan: `ledger/CURRENT_PHASE.md`, ledger tail, `00-working-protocol.md`, `06-privacy-memory-center.md`
- Repo: ADR-043 (memory personalization controls), ADR-026 (provenance memory), UI-3/UI-4 view-test patterns in `Tests/AURAIntegrationTests/`
- Code: `Sources/AURA/AuraMenuView.swift:90-200` (`MemoryRowView`, `MemoryCorrectionSheet`, `AuraMemoryCorrectionDraft`), `AuraMenuView_Content.swift:75-85` (sheet presentation), `AuraMenuView_Tabs.swift:355-540` (privacy tab), `:160-200` (models tab), `AuraAppModel_ProductState.swift:700-760`, `AuraKernel_RuntimeAPI.swift:540-600`, `AuraAccessibilityIdentifiers.swift`, `ProductUIState.swift` copy table
- Owner decision D-5 recorded.

## Hard boundaries

- **Allowed files:** `AuraMenuView.swift` (sheet + row), `AuraMenuView_Tabs.swift` (privacy/models copy + IDs), `AuraAccessibilityIdentifiers.swift`, `ProductUIState.swift` (copy), tests, `docs/decisions/ADR-069-*.md`, ledgers.
- Forbidden: changing `MemoryEngine` semantics (append-and-link correction, deletion receipts, contradiction handling), changing key names in `AuraCopy`, editing the audit/security exclusion rule.

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G5-1 | Defect fixed: sheet draft is `@State`, survives parent re-render; Save disabled on empty trimmed draft; regression test | `integration` test that publishes on the model mid-edit and asserts the draft persists |
| G5-2 | Accessibility identifiers for every memory control (list in `06-…md` §3.2); uniqueness/non-localized tests green | `unit`/`integration` |
| G5-3 | Copy hygiene: the listed literals migrated EN/TR; grep gate zero English literals in the privacy/models sections | `grep` script output in `evidence/PA-5/`; copy guard |
| G5-4 | D-5 relabel applied with the append-and-link caption; sheet title updated | copy keys; view test |
| G5-5 | Live driver: seed → edit (with runtime publishing) → save → linked row; delete → receipt; contradiction → resolve; retention; export parses and excludes audit/security | `live-local` transcript + `evidence/PA-5/export.json` (redacted) |
| G5-6 | Truthful indicators on this tab: six permission rows `Verildi`; integrations zero `Bağlı değil` | `live-local` labels + `owner-attested` |
| G5-7 | Full verification + governance: suite ×2–3, ADR-069, repo ledgers, `CURRENT_STATE` | `evidence/PA-5/` |
| G5-8 | Machine coherence | validator OK, `awaiting-approval` |

## Per-gate procedure

- **G5-1:** rewrite the sheet; delete the draft class; write the regression test first (red), then fix (green).
- **G5-2:** add IDs; attach; run the pinned ID tests.
- **G5-3:** migrate literals one by one; keep exact English; write genuine Turkish; grep gate.
- **G5-4:** relabel per D-5; caption.
- **G5-5/G5-6:** stable-signed bundle; `open -a`; driver legs from `06-…md` §6.
- **G5-7/G5-8:** closing sequence.

## Evidence template

```text
## SEQ-00NN — <ISO> — PA-5 — G5-k PASSED
- evidence: …
- verified: …
- adr: ADR-069
```

## Risks / reverting

If the `.sheet(item:)` identity interacts badly with `State(initialValue:)`, the fallback is a `@StateObject` draft — still no `let` re-init. Reverting is restoring the allowed files.

## Session script

Protocol §5, then G5-1 → G5-8. End with `awaiting-approval`.

## Cognitive completion gate

(1) What exactly was lost before the fix, and which test would have caught it? (2) Which control has no identifier now? (expected: none) (3) Which English literal remains on the tab? (expected: none)
