# EV-SP-019-20260824-LIVE-CONTROLS-04 — user-present memory controls attempt

- **Timestamp:** 2026-08-24T10:50:50Z (UTC)
- **Session / actor:** `AURA-SP-019-ATTEMPT-20260824`; Codex with explicit user authorization to use Computer Use.
- **Prompt / scope:** SP-019 / OPEN-09 / R8 only. SP-020 was not opened.
- **Branch / commit:** `main`; `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`.
- **Environment:** macOS 27-era Apple Silicon; unsigned local build `/tmp/aura-sp019-final-app/AURA.app`; executable SHA-256 `e7409130cc44654cb015691240d9c7d2621b1acdc8ab0209eaad7fcd55952413`; isolated Foundation home `/tmp/aura-sp019-ui-home.BUe4pK`; live database hash `3bdd6dd277b0bf2a6a276c9ebbb9969dc8da3fc3b1c072e92df7619958289781`.
- **Procedure:** launched the final app with `open -n -a /tmp/aura-sp019-final-app/AURA.app --env CFFIXED_USER_HOME=/tmp/aura-sp019-ui-home.BUe4pK --env HOME=/tmp/aura-sp019-ui-home.BUe4pK --env AURA_SP019_LIVE_ACCEPTANCE=1`; operated the Privacy and Conversation controls in the user-present window. The Computer Use permission prompt was accepted only after the user explicitly authorized Computer Use. The native `@oai/sky` AURA accessibility pipe continued to close on this app's tree, so the skill-permitted AppleScript/System Events structured UI fallback was used; no raw screenshot, audio, secret, token, private account data, or unredacted model output was written to repository evidence.

## Direct observations

- **Restart preference:** selected `Concise`, saved it, observed the UI text `Saved with purpose: user-controlled personalization profile; scope: global; retention: indefinite.`, used the AURA menu's `Quit AURA`, relaunched the same final bundle with the same isolated home, and observed `responseLength: concise`, `localOnly: true`, and the saved metadata row after reload. This is direct user-present restart evidence for the bounded preference profile.
- **Inspection / provenance / scope:** the Privacy panel showed `4 visible of 4 records` after the live turns. The visible rows exposed memory class, subject, purpose, provenance, confidence, sensitivity, retention, and scope. The audit exclusion text was visible: `Audit/security memory is excluded from inspection and export and cannot be corrected or deleted here.`
- **Correction:** opened the live `workingConversation` row's `Correct` control, entered the redacted statement `User corrected: the local project fact request was not tool-verified; do not treat this conversation as a verified project fact.`, saved it, and observed the corrected statement with `Purpose: bounded local intent continuity`, `Provenance: userStated`, `Confidence: 100%`, `Retention: sessionScoped`, and the session scope in the UI.
- **Retention:** invoked `Run retention cleanup`; the visible record count remained stable because no expired disposable record was present. No active record was purged.
- **Policy non-weakening:** enabled `Allow remote context` and pressed `Save preference`; the UI showed `Error. Memory preference save failed: Permission denied: user preference cannot enable remote context while machine policy is local-only`. The checkbox was returned to off and the local-only preference was saved again. The profile projection remained `localOnly: true`.
- **Ambiguity / tool boundary:** a read-only request for verified local project evidence was submitted. The live response explicitly refused to execute the requested real-world action, and a follow-up reference produced a visible `Diagnostic: ambiguous` state. This does not prove a resolved multi-turn reference, verified tool fact, or destructive-action confirmation path.
- **Export:** the live `Denetim dışı belleği dışa aktar` control opened the native Save panel and accepted navigation to `/tmp`; no export file was located by the post-action filesystem check. Export is therefore not claimed as passed.
- **Deletion:** one disposable `workingConversation` row is still visible. Its Delete control was not activated because the product does not expose a recoverability/undo guarantee and Computer Use policy requires confirmation immediately before an irreversible delete.

## Acceptance verdict

- **Met live:** bounded preference save/reload; purpose/scope/retention display; inspect and correction; retention cleanup invocation; audit/security exclusion display; local-only policy rejection and restoration.
- **Partial / not met:** verified project fact from tool evidence, resolved multi-turn reference, destructive ambiguity clarification, contradiction surfacing/resolution, live export artifact, live delete receipt, and direct transport observation. No live conflict section appeared in this disposable profile; the visible ambiguous diagnostic was not promoted to a successful resolution.
- **Overall:** SP-019 remains `in_progress`; the eight-scenario completion gate is not met and SP-020 is not safe to start.

## Limitations and falsifier

- A successful native export artifact, a live tool-result provenance chain, a resolved reference, a visible conflict plus resolution, and a deletion receipt would be required to falsify the incomplete verdict. The absence of a located export file and the unconfirmed destructive action are direct blockers, not inferred passes.
- The temporary profile is isolated by `CFFIXED_USER_HOME`; the application is unsigned/unnotarized and no release, install, provider, remote transport, TCC mutation, commit, push, merge, signing, or deploy was performed.
