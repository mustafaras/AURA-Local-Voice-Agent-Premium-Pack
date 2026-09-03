# EV-SP-019-20260824-LIVE-CONTROLS-06

- **Evidence ID:** `EV-SP-019-20260824-LIVE-CONTROLS-06`
- **Prompt / gap:** SP-019 / OPEN-09 / R8
- **Timestamp:** 2026-08-24T11:15:56Z
- **Branch / commit:** `main`; `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`; intentionally dirty worktree preserved
- **Class:** Direct user-present structured UI export evidence
- **Environment:** final local `/tmp/aura-sp019-final-app/AURA.app`, LaunchServices-launched isolated Foundation home `/tmp/aura-sp019-ui-home.BUe4pK`, AURA process PID `6853`, local-only machine policy
- **Procedure:** In the live AURA Privacy tab, activate the visible `Denetim dışı belleği dışa aktar` control, use the native Save panel with `Where: tmp`, save as `aura-memory-sp019-export.json`, and inspect only redacted structural metadata.
- **Result:** The file was located at `/tmp/aura-memory-sp019-export.json`; `jq` parsed keys `conflicts`, `generatedAt`, and `records`; record count was 203; no audit key was present; a redacted string scan found no raw audio, screenshot, token, or secret marker. SHA-256: `b00a4e3958adb932e2772def68bea59970fd29fd9ba237f56271c4aae87f2857`.
- **State result:** Export is now directly observed and passes its postcondition. SP-019 remains `in_progress` because deletion receipt, contradiction resolution, verified tool fact, resolved reference, and direct transport trace remain open. SP-020 remains unopened.
- **Limitations:** The exported JSON was not copied into repository ledgers or context; only its safe path, hash, schema keys, count, and exclusion checks are recorded. No raw export content, screenshot, audio, secret, token, private account data, or unredacted model output was retained. Permanent Delete was not activated because action-time confirmation is still required.
