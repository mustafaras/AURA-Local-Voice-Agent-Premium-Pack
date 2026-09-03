# EV-SP-001-20260815-CANCELLATION-12

- **Timestamp:** User-present interaction window `2026-08-15T11:10:00Z`–`2026-08-15T11:17:34Z`; cancellation shortcut at `2026-08-15T11:12:44Z`, Calculator accepted mutation at `2026-08-15T11:15:43Z`, full normal restart check at `2026-08-15T11:17:30Z`.
- **Prompt/gap:** `SP-001` / `OPEN-02` only. `SP-002` was not opened.
- **Authority:** The user explicitly authorized the current local AURA build, safe observation, `/bin/sleep 20` cancellation/emergency-stop, redacted read-only verification, and reversible Calculator mutation. No denied action was executed. No TCC, install, dependency/model/provider, telemetry/beta, signing, release, deploy, commit, push, or merge action occurred.
- **Repository:** branch `main`; live start `HEAD == origin/main == 813a504ede1ac1566773eda04e80d7f6160e1179`; worktree contained the pre-existing control-plane dirt plus the bounded OPEN-02 source/test change. Environment: macOS 27 / Apple Silicon arm64.
- **Bundle:** unsigned local bundle `/tmp/aura-sp001-live-cancel-20260815/AURA.app`; executable SHA-256 `49d0c22b8edd11fda95899b861c7d6a1b1c455c78fcea0e2222c2d75abb76132`.
- **Evidence class:** Direct user-present live UI interaction plus read-only local redacted SQLite metadata and read-only process checks. No screenshot, raw audio, secret, token, private account data, or unredacted model output was copied into the repository. The live SQLite database was not copied or modified by the evidence procedure.

## Direct live procedure and result

1. Built the current unsigned app bundle with `BUILD_DIR=/tmp/aura-sp001-live-cancel-20260815 ./scripts/build-app-bundle.sh`; launched only that bundle with `/usr/bin/open`.
2. Submitted the safe typed request `run /bin/sleep 20`. The visible confirmation displayed the requested `shell.exec`, risk, expiry, and redacted trace prefixes `3460A57D` / `0C6F98BC`.
3. Sent the authorized emergency-stop shortcut `Command-Shift-Escape` while the confirmation was pending. The read-only redacted store query recorded the exact terminal chain for that request: `confirmation.requested` row `56` → `confirmation.cancelled` row `57` → `policy intent.blocked` row `58`, all with correlation prefix `3460A57D` and causation prefix `0C6F98BC`. The UI remained fail-closed with `Blocked: confirmationDenied`; no `tool.result` row was produced. No `/bin/sleep 20` process was observed.
4. Re-armed generated input through the visible AURA control. Opened Calculator, submitted `close Calculator`, and observed a visible `app.terminate` confirmation. The first confirmation was intentionally left until expiry; rows `59`–`61` recorded `requested` → `expired` → `policy blocked`, and Calculator remained running. This was a safe timeout, not a denied action.
5. Submitted `close Calculator` again. The visible confirmation was accepted through the Allow Once control. Rows `62`–`64` recorded `confirmation.requested` → `confirmation.accepted` → `tool.result app.quit verified` for correlation prefix `8351BDF1` and causation prefix `609D2F54`. The UI reported `Quit com.apple.calculator.` and an independent read-only process check found no Calculator process.
6. Quit AURA normally through `AURA → Quit AURA`, reopened the same unsigned bundle, and observed a fresh idle UI with no carried-over actionable confirmation. A second normal quit left no AURA, Calculator, or `/bin/sleep 20` process.

## Completion gate

- **Correlation/causation:** The cancellation chain and accepted Calculator chain retain matching redacted correlation/causation prefixes across confirmation, policy/tool outcomes.
- **Runtime health:** AURA remained fail-closed during emergency stop and returned to a normal fresh idle/restricted state after re-arm/restart; no crash or forced termination was used.
- **Displayed confirmation:** The live UI displayed the confirmation surface and opaque trace prefixes before both cancellation and mutation decisions.
- **Truthful execution:** Cancellation produced no execution result; expired confirmation produced no execution; the accepted mutation produced `app.quit` and `verified`.
- **Independent verification:** Calculator was absent after the accepted close; `/bin/sleep 20` was absent after cancellation; restart did not replay either request.
- **Fail-closed cases:** Cancellation, expiry, and prior post-fix deny/dismissal/changed-plan/replay/concurrent-turn cases remain blocked without execution. The prior direct residual bundle covers the cases not repeated in this narrow cancellation run.

## Cognitive completion gate

- **Exact symptom:** Emergency stop previously prevented execution but left the pending confirmation to expire, so no distinct live cancellation terminal trace existed.
- **Mechanism/root cause:** The runtime confirmation lifecycle lacked `ConfirmationResolution.cancelled`, and `triggerEmergencyStop()` did not resolve a pending confirmation. The affected layer was the AURA app-model emergency-stop/confirmation boundary.
- **Direct change and acceptance procedure:** Added the bounded `cancelled` resolution and resolved pending confirmation after emergency stop; added an integration test; rebuilt and ran the authorized live cancellation, expiry, reversible mutation, verification, and normal restart procedure.
- **Evidence ID/class:** This record, `EV-SP-001-20260815-CANCELLATION-12`, is direct user-present live UI plus redacted persistence/process evidence. Supporting source/build/test evidence is the current dirty-tree product/test change and the passing full test/validator runs; neither is used as a substitute for the live record.
- **Falsifier:** A future run showing execution after the emergency-stop cancellation, a missing/mismatched terminal cancellation chain, a replay after restart, a raw-data persistence leak, or a false verification result would falsify this conclusion.
- **Residual risk:** First-pass R2–R12, FINAL, TCC, provider, beta, signing, release, deployment, and telemetry gates remain separate and open. They are outside `SP-001` / `OPEN-02` and are not claimed complete.
- **Why SP-002 is safe from this dependency:** The `SP-001` direct live completion gate is now satisfied, the source regression and governance validators pass, and no `OPEN-02` residual remains. `SP-002` is therefore the next eligible prompt but remains pending/not opened in this session.

## Limitations

The live record contains bounded identifiers, outcome labels, timestamps, bundle hash, and process presence/absence only. It excludes raw command output, screenshots, audio, full identifiers, and private payloads. The accepted Calculator action is reversible by relaunching Calculator; it was the only accepted mutation. No release or delivery claim follows.
