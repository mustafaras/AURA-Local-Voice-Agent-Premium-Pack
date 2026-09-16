# PA-5: Privacy & Memory Center — every "Düzelt" works, every state is true

**Phase:** PA-5. **Effort:** S–M. **ADR:** ADR-069 (new) — "Memory Center correctness and copy hygiene".
**Owner instruction covered:** "gizlilik ve bellekte de bir sürü düzelt öğesi var bunlar kesin net doğru çalışır şekilde düzeltilmeli".

---

## 1. Evidence

| Fact | Evidence |
| --- | --- |
| What "Düzelt" is | `memory.correctShort` = EN "Correct" / TR "Düzelt" (`ProductUIState.swift:508`), rendered once per mutable memory record next to "Sil" (`AuraMenuView.swift:120-127`, `record.canMutate`); sheet title `privacy.correct` = "Belleği düzelt" (`:706`); the action appends a linked correction record (`AuraAppModel_ProductState.swift:716-730`, `AuraKernel_RuntimeAPI.swift:549-563`, ADR-043) |
| **Defect: the correction draft is lost on re-render** | `MemoryCorrectionSheet` holds `let draft: AuraMemoryCorrectionDraft` and constructs a **new** draft in `init` from `record.statement` (`AuraMenuView.swift:147-156`); `AuraMemoryCorrectionDraft` is `final class … : ObservableObject` with a plain `var statement` (no `@Published`) (`:190-196`); the `TextEditor` binding writes into that object (`:167-172`). Because the sheet observes `model` (`@ObservedObject`, ~30 `@Published` properties incl. status/latency), any model publish re-evaluates the parent, re-creates the sheet struct, and the binding's `get` now returns the original statement — the owner's typing disappears. Saving after such a re-render appends the *unchanged* statement |
| The sheet is presented from the content view | `AuraMenuView_Content.swift:80` `.sheet(item: $model.memoryCorrectionTarget)` |
| Untranslated strings on the Privacy tab (F-005 class) | `AuraMenuView_Tabs.swift:412` "Response length", `:420` "Allow remote context", `:425` `.help("The machine policy can reject…")`, `:436-438` "Saved with purpose…" / "No saved profile.", `:469` "Audit/security memory is excluded…", `:510-511` "Unresolved contradiction…" / "Resolution recorded:"; Models tab `:175` "Reference-voice cloning is not enabled…"; deletion-receipt a11y label tail `:496` "The record content is gone; only this receipt and the audit event remain." |
| Permission indicators can show negative states forever | `AuraMenuView_Tabs.swift:358-376` render `PermissionState.title(for:)` — after PA-1 these must all read `Verildi`; the screen-observation row has Grant/Settings buttons (`:371-390`) |
| Cloud-context rows | `:391-401` three honest states driven by `isCloudContextPolicyAllowed` and `memoryPreferenceProfile.localOnly` — unchanged |
| Memory operations available | search, export (`exportMemory`, `NSSavePanel`), retention (`enforceMemoryRetention`), conflicts (`resolveMemoryConflict` keep-previous / keep-new), delete with receipt (`lastMemoryDeletionReceipt`), preference profile save/clear |
| No accessibility identifiers on memory controls | `AuraAccessibilityIdentifiers.swift` has none for correct/delete/save/conflict buttons (grep 2026-09-15) — the live driver cannot address them today |

## 2. Problem statement

The Privacy tab is where the owner audits what AURA remembers. It carries one real defect (edits vanish), several English-only strings, and no way for the acceptance driver to prove the operations work. "Works correctly" must be demonstrated, not asserted.

## 3. Design

### 3.1 Fix the correction sheet

- Replace `AuraMemoryCorrectionDraft` with `@State private var statement: String` initialised from `record.statement` via `init(model:record:)` → `_statement = State(initialValue: record.statement)`. `@State` survives parent re-renders; the class goes away.
- Save path unchanged (`model.correctMemory(record.id, statement:)`); empty/whitespace statements are already rejected by the kernel (`AuraKernel_RuntimeAPI.swift:554-557`) — the Save button is additionally disabled for an empty trimmed draft so the failure is not discoverable only after a click.
- Regression test: construct the sheet, mutate the draft, trigger a parent re-render (publish on the model), assert the draft persists (view-level test in `AURAIntegrationTests`, pattern from UI-1's view-construction tests).

### 3.2 Accessibility identifiers for every memory control

Add to `AuraAccessibilityID`: `memoryRow(id)`, `memoryCorrect(id)`, `memoryDelete(id)`, `memoryCorrectionEditor`, `memoryCorrectionSave`, `memoryCorrectionCancel`, `memoryConflictKeepPrevious(id)`, `memoryConflictKeepNew(id)`, `memorySearch`, `memoryExport`, `memoryRunRetention`, `memoryPreferenceSave`, `memoryPreferenceClear`. Pinned by the existing uniqueness/non-localized tests.

### 3.3 Copy hygiene

Every literal in §1 moves into `AuraCopy` with genuine Turkish; grep gate: zero `Text("…")` / `Toggle("…")` / `Picker("…")` / `.help("…")` English literals in `AuraMenuView_Tabs.swift` privacy/models sections. Table floor (>150 keys) unaffected.

### 3.4 Label semantics (D-5)

Per the recommendation, `memory.correctShort` TR becomes "Düzenle" (EN "Edit") and `privacy.correct` becomes "Bellek kaydını düzenle" / "Edit memory record". The key names and the append-and-link behavior (ADR-043) do not change; the sheet's explanatory caption states EN "Saves a corrected statement linked to the previous one; nothing is overwritten." / TR "Öncekine bağlı düzeltilmiş bir ifade kaydeder; hiçbir şey üzerine yazılmaz."

### 3.5 Truthful indicators after PA-1/PA-3

After PA-1 the six permission rows must read `Verildi`; after PA-3 the integrations section must show no `Bağlı değil`. PA-5's gate re-checks both on this tab (they are PA-1/PA-3 outcomes, verified here from the owner's vantage point).

## 4. Files touched

`Sources/AURA/AuraMenuView.swift` (sheet), `AuraMenuView_Tabs.swift` (privacy/models copy, IDs), `AuraAccessibilityIdentifiers.swift`, `ProductUIState.swift` (copy), tests, ADR-069, ledgers.

## 5. Tests

- **New:** draft-persistence regression; Save disabled on empty draft; a11y-ID additions; copy keys EN/TR; grep gate script for literals.
- **Unchanged:** `MemoryEngine` tests (correction linking, deletion receipts, contradiction detection), copy-table guard, reducer determinism.

## 6. Live acceptance (driver)

1. Seed a memory via a typed turn ("adımı Mustafa olarak hatırla" — or the repo's existing memory-seeding utterance from R9 tests) → row appears.
2. Click `memoryCorrect(id)` → type a new statement → wait 5 s with the runtime publishing status ticks → text still present → Save → new row with provenance "user correction", old row linked; `lastOperationMessage` shown.
3. Delete → receipt rendered with record ID and time; row gone after refresh.
4. Create a contradiction (two conflicting statements) → conflict box → keep-new → resolution summary rendered.
5. Run retention; export to `$TMPDIR` → JSON parses, excludes audit/security classes.
6. Permission and integration indicators on this tab: zero negative states (owner-attested + driver labels).

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| `@State` init pattern conflicts with the `item:` sheet identity | The sheet is keyed by `record.id` via `.sheet(item:)`; a new record yields a new view identity, so `State(initialValue:)` re-seeds correctly |
| Relabel "Düzenle" confuses with a destructive edit | Caption in §3.4 states append-and-link explicitly |
| Copy migration changes pinned strings elsewhere | Only the listed literals move; guard tests decide |

## 8. Owner decisions consumed

D-5.
