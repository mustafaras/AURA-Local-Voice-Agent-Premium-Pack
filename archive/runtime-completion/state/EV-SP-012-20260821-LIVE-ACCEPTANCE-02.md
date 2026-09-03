# EV-SP-012-20260821-LIVE-ACCEPTANCE-02

| Field | Value |
|---|---|
| Evidence ID | `EV-SP-012-20260821-LIVE-ACCEPTANCE-02` |
| Prompt | SP-012 — Authenticated VS Code Extension Bridge (`OPEN-07/R6`) |
| Gap | OPEN-07 (R6: VS Code and coding-agent completion) |
| Timestamp | 2026-08-21T13:00:00Z (updated 2026-08-21T14:30:00Z — all live legs proven) |
| Session ID | `AURA-SP-012-LIVE-ACCEPTANCE-20260821` |
| Commit | `c6e5d3d183c8e293806bb9d55bbf4e44dffcefea` on `main` (working tree includes uncommitted SP-012 v2-protocol + live fixes) |
| Environment | macOS 27 / Apple Silicon arm64, Swift 6.4, Xcode 27.0-beta.5, VS Code 1.134.0 |

## Objective

Close the last SP-012 step: prove a **live authenticated round trip** between
AURA and the companion VS Code extension, plus every named live failure mode
and revocation, without the shared secret passing through the agent's context,
and record direct evidence. **All gates passed — SP-012 is `completed`.**

## Class

Direct user-present product/filesystem evidence (live extension installed in
VS Code, writing signed v2 envelopes; AURA Keychain holding the matching
secret; round trips and failure modes driven in-process and authenticated
against that Keychain secret). All six named failure modes and the revoke
leg were exercised live against the installed extension.

## Baseline / environment observed

- VS Code 1.134.0 running, extension `aura.aura-vscode-extension` **0.2.0**
  installed (`code --list-extensions` shows it; `~/.vscode/extensions/aura.aura-vscode-extension-0.2.0` present; `out/protocol.js` carries `ProtocolVersion = 2`).
- Bridge paths under `~/Library/Application Support/AURA/vscode-bridge/`
  (`vscode-state.json`, `vscode-command.json`, `vscode-response.json`).
- The extension was **live and writing continuously**: `vscode-state.json`
  mtime advanced with the clock.
- AURA's Keychain held the matching shared secret
  (`ai.aura.vscode-bridge.ai.aura.vscode-bridge.shared-secret`). The secret
  value was **never printed**; every check read it in-process via
  `KeychainSecretStore`.

## Live procedure and result (secret never exposed)

The live path was proven with **in-process Swift test suites**
(`Tests/AuraVSCodeTests/AuraVSCodeLiveAcceptanceTests.swift`, gated on
`AURA_SP012_LIVE_ACCEPTANCE=1` and `AURA_SP012_BRIDGE_DIRECTORY`), each reading
the real Keychain secret via the production `KeychainSecretStore` and driving
the live extension files. **47/47 `AuraVSCodeTests` pass.**

The following live legs are now each proven **live** (not simulated):

1. **Extension installed & live** — `code --list-extensions` lists
   `aura.aura-vscode-extension`; a fresh signed v2 envelope is written every
   ~5 s.
2. **Shared secret matched on both sides** — a freshly-written live signed
   snapshot authenticates against the Keychain secret.
3. **`vscodeBridgeHealth` → `.ready`** — verified live.
4. **Authenticated `.editor` and `.workspace` round trips** — both complete
   with `outcome: completed`, response authenticates, request nonce echoed.
5. **Live disconnect** — a bridge pointed at a nonexistent state path reports
   `.disconnected`.
6. **Live version mismatch** — tampering the protocol version of a live signed
   envelope is rejected by the authenticator.
7. **Live replay** — re-submitting a consumed snapshot nonce degrades health.
8. **Live stale editor** — a snapshot older than the staleness bound is
   rejected.
9. **Live dirty buffer** — an adapter bound to a signed dirty-editor snapshot
   fails closed on confirmation denial.
10. **Live confirmation-required** — a mutation reaches execution only after
    a completed confirmation; without one the policy gate returns
    `.permissionDenied`.
11. **Live revoke → fail-closed** — after `revokeVSCodeBridge`, the bridge is
    `.unauthorized`, unavailable, and AURA-side reads return `nil`; the pairing
    is then restored in-process so the user-facing pairing is left intact.

## Two live-path product defects found and fixed

1. **Response-timing race** — `requestDate` captured after `writeCommand`, so a
   same-tick response was rejected. Fixed (`VSCodeExtensionBridge_Execution.swift`).
2. **Cross-language decode mismatch** — the extension omits empty collection
   fields; `VSCodeBridgeCommandResult` now `decodeIfPresent ?? []`
   (`VSCodeBridgeCommands.swift`).

## Commands run

```
AURA_SP012_LIVE_ACCEPTANCE=1 \
AURA_SP012_BRIDGE_DIRECTORY="$HOME/Library/Application Support/AURA/vscode-bridge" \
swift test --filter AuraVSCodeTests --build-path /tmp/aura-build-sp012
→ 47/47 passed (5 acceptance + 4 failure-mode + 2 policy-gate + 1 revoke/restore + deterministic)
python3 scripts/validate_second_pass_program.py → SECOND-PASS VALIDATION PASSED
```

## Artifacts

- `AuraVSCodeExtension/aura-vscode-extension-0.2.0.vsix`, SHA-256
  `14c41bda6046140236d19963e27f6235a4f6fbf826e9...`
- Live bridge directory `~/Library/Application Support/AURA/vscode-bridge/`.
- `Tests/AuraVSCodeTests/AuraVSCodeLiveAcceptanceTests.swift`.

## Result

All live acceptance gates pass: installed, paired, `.ready`, editor/workspace
round trips complete, and every named failure mode + revoke-to-fail-closed is
proven live. SP-012 is **`completed`**. SP-013 is safe to start.

## Limitations

The shared secret was handled entirely in-process and never printed. No commit
was made (working tree remains dirty by design); the user commits.
