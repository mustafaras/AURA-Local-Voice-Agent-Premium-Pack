# EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14

- **Evidence ID:** `EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14`
- **Prompt / gap:** SP-019 / OPEN-09 / R8
- **Timestamp:** 2026-08-25T06:43:51Z
- **Branch / commit:** `main`; `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`; intentionally dirty worktree carrying the SP-019 delivery
- **Class:** Consolidated user-present acceptance of all eight R8 live/product scenarios on one build
- **Environment:** single build `/tmp/aura-final-app/AURA.app`, main executable SHA-256 `fccf15204202b7c3f71815a2ff547e5706907dfe2caa1d30dea29d0157989f00`; LaunchServices-launched with isolated `CFFIXED_USER_HOME=HOME=/tmp/aura-final-home.ddFDhE`; final database SHA-256 `9d6066de27dab5e3d6cfd4b259a5b4817d6b17195122de56d1fbcd23163a0a02` (12 records, 1 conflict); machine policy local-only

## Why this record exists

The eight scenarios previously carried live evidence spread across three builds
(`e7409130`, `efe42a2c`, `ee4d9735`). A completion claim should not rest on
three binaries, so every scenario was re-run against one build. Nothing below is
carried over from an earlier run.

## Scenario results

| # | Scenario | Direct observation |
|---|----------|--------------------|
| 1 | Preference across restart, with purpose/scope/retention | `Concise` saved; UI showed `Saved with purpose: user-controlled personalization profile; scope: global; retention: indefinite.` After a full quit/relaunch: `responseLength=Concise`, `allowRemoteContext=0`, metadata line unchanged. |
| 2 | Project fact from verified tool evidence | A user-confirmed `run /bin/date` wrote `projectFact` `shell.execute:/bin/date`, statement `` `/bin/date` reported: Tue Aug 25 09:20:48 +03 2026 ``, provenance `{"observed":{"source":"user"}}`. |
| 3 | Multi-turn reference resolved | `open the file` returned `Blocked: ambiguous` with a clarifying question while two candidates were plausible; `open the file alpha` resolved to alpha and bound the slot. Memory records: turn 3 `classified intent: fileOpen` (no slot), turn 4 `; slots: filePath`. |
| 4 | Contradiction surfaced and resolved | A second confirmed `run /bin/date` (`09:21:51`) collided on the same fact key, raising conflict `ED0B40DD-2599-4750-88CF-B3E61B2A5D5F`; both records retained. Activating `Keep new` recorded `resolution={"supersededExisting":{}}`. |
| 5 | User correction applied | The row's `Correct` control opened the sheet; the corrected statement was saved as a new `workingConversation` record carrying `supersedes=80544B5D…`, so provenance is preserved rather than overwritten. |
| 6 | Inspection, deletion, export, retention, audit exclusion | Rows exposed class, subject, purpose, provenance, confidence, sensitivity, retention, and scope. `Run retention cleanup` was invoked and purged nothing (no expired record present). Export wrote a 12-record bundle. One disposable record was permanently deleted with a receipt. The exclusion statement `Audit/security memory is excluded from inspection and export and cannot be corrected or deleted here.` was visible throughout. |
| 7 | Memory cannot authorize a risky action | Enabling `Allow remote context` was refused: `Error. Memory preference save failed: Permission denied: user preference cannot enable remote context while machine policy is local-only`, and local-only was restored. Separately, a mutation-tier shell command left unconfirmed ended `Blocked: confirmationDenied` — `That needs explicit confirmation, and I don't have a way to get it from you yet.` — and produced no memory record. |
| 8 | Privacy-safe evidence only | Only paths, hashes, counts, schema keys, and redacted UI strings were retained. The export artifact was deleted from disk after verification; its hash is recorded here. |

## Deletion detail (irreversible step)

Under the user's explicit authorization for disposable test records only, the
search filter was set to isolate exactly one row (`1 visible of 9 records`) —
the driver refuses to click Delete otherwise — and record
`intent:B5C8D56C-FF3F-47AC-B867-EC6182DB357A` (`workingConversation`) was
permanently deleted. It is absent from `memory_records` afterwards. The Privacy
tab then rendered:

```
Memory deletion receipt. Record F435498A-379B-45C3-B7B8-668BCF2855E3,
class workingConversation, reason user requested from R9 Memory Center,
deleted at 2026-08-25T06:38:40Z. The record content is gone; only this
receipt and the audit event remain.
```

This also confirms the accessibility fix recorded in
`EV-SP-019-20260824-LIVE-DELETION-RECEIPT-10`: the receipt now announces its
own content instead of only its title.

## Export detail

`/tmp/aura-final-export.json`, SHA-256
`af627270133ae0204e0005ba26af647ee501007ccef976136822b60ea93d37fc`. Keys
`conflicts`, `generatedAt`, `records`; 12 records; 1 conflict; classes present
were `projectFact`, `userPreference`, `workingConversation` — **no
`auditSecurity`**; a marker scan for `sk-`, `akia`, `private key`,
`-----begin`, `password`, and `bearer ` found none. The file was removed from
disk after verification.

## Transport

Two socket-table observations of the live acceptance processes:
PID 24980, 78 samples, 0 endpoints, 0 non-loopback peers
(`/tmp/aura-final-transport.json`, SHA-256
`2bf8c05602e72907fad42e554f4cb3ffc9b17610030cd4a724bd5d5af43e9134`); PID 27292,
60 samples, 0 endpoints, 0 non-loopback peers
(`/tmp/aura-final-transport2.json`, SHA-256
`98f1f65a604df57da59624da3f8e78cb0c518d7392caf7365a9cf27db13ac819`).

## Falsifier

A preference that did not survive relaunch, a `projectFact` with non-`observed`
provenance, a reference resolving while two candidates remained plausible, a
contradiction that overwrote rather than retained, a correction that lost its
supersession link, a deleted record still present, `auditSecurity` inside the
export, a preference save that widened machine policy, or any non-loopback peer
would falsify this acceptance.

## Limitations

`/bin/date` is a real verified tool observation but not a repository fact; the
sandboxed app could not read the repository path. Retention cleanup was invoked
and correctly purged nothing, so expiry-driven purging is exercised only by the
deterministic suite. `revealPrefixes` still requires a path-shaped target, so
reveal-by-reference remains out of scope. The app is unsigned for distribution
and unnotarized; no release, install, provider, remote transport, or TCC
mutation occurred during acceptance.
