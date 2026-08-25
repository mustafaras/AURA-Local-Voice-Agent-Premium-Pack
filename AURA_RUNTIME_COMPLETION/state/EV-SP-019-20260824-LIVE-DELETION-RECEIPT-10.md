# EV-SP-019-20260824-LIVE-DELETION-RECEIPT-10

- **Evidence ID:** `EV-SP-019-20260824-LIVE-DELETION-RECEIPT-10`
- **Prompt / gap:** SP-019 / OPEN-09 / R8
- **Timestamp:** 2026-08-24T15:02:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`
- **Class:** Direct user-present acceptance — permanent deletion and its receipt
- **Environment:** `/tmp/aura-sp019-live-app/AURA.app`, executable SHA-256 `efe42a2c18dde76349bd1d062bbaced81f8b21aa6904b90770d2cfbbcbe93e3f`; isolated `CFFIXED_USER_HOME=HOME=/tmp/aura-sp019-ok.sDZm8e`

## Authority

The user gave explicit action-time authorization for exactly one irreversible
step: permanently deleting **one disposable `workingConversation` test record**
in the isolated `/tmp` profile. No other record was deleted, no real user data
was touched, and audit/security memory is not user-deletable by construction.

## Procedure and guard

The Privacy tab's memory search was set to `EC01E9E7` so the list showed
`1 visible of 5 records`. The driver **refuses to click Delete unless the
filter has isolated exactly one record** — two earlier attempts were refused by
this guard (`5 visible of 5`, then `0 visible of 5` after the field was not
cleared), and no deletion occurred on either. Scroll-bar arrows are also
`AXButton`s; the control search additionally requires a real control width, and
one earlier click that landed on a scroll arrow deleted nothing.

## Result

- Target: record `441E1B60-4F3A-4D42-A21D-0193661FAF8C`,
  `workingConversation`, subject `intent:EC01E9E7-BA90-4E41-84D2-33755A8E1C5A`.
- The row's `Delete` control (right of the `Correct`/`Delete` pair at the row's
  own button line) was activated.
- Database after: the record is **gone**; 4 records remain
  (`CA0439EA-…`, `D160D983-…`, `D3B41C07-…`, `67B61DBB-…`).
- The Privacy tab afterwards reported `0 visible of 4 records` under the still
  applied `EC01E9E7` filter — the deleted record cannot be found by the search
  that isolated it moments earlier.
- A persistent **`Memory deletion receipt`** element rendered in the Privacy
  tab's memory controls. Before this session's change the kernel discarded the
  engine's `MemoryDeletionReceipt` (`_ = try await …`) and no receipt could
  reach the UI at all.

## Follow-up defect found and fixed

The receipt used `.accessibilityElement(children: .combine)` together with
`.accessibilityLabel("Memory deletion receipt")`. In SwiftUI the explicit label
*replaces* the merged child text, so VoiceOver announced only the title and the
record id, class, reason, and timestamp — the entire content of the proof —
were unreachable. The label is now composed from the receipt's fields. The live
capture above was taken with the pre-fix build; the fix changes only the
announced label, not the receipt data path, and the full matrix was re-run
green afterwards.

## Falsifier

A deleted record still present in `memory_records`, a receipt that vanished on
the next unrelated operation, or a receipt carrying the deleted statement would
falsify this result. The receipt deliberately carries no deleted content.

## Limitations

The receipt is session state by design and does not survive an app restart; its
durable counterpart is the `MemoryDeletedEvent` audit entry, which likewise does
not carry the deleted subject or statement. One record was deleted; the
remaining disposable records were left untouched because the authorization
covered exactly one. No commit, push, merge, signing, release, deployment,
provider action, or permission mutation occurred.
