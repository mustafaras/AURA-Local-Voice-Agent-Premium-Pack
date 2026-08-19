# EV-SP-011-20260818-COMPUTER-UI-SCOPE-05

- **Prompt / gap:** SP-011 / OPEN-06 (R5 productivity live acceptance)
- **Timestamp:** 2026-08-18T12:53:09Z
- **Branch / commit:** `main` / `33688e2a54f1e5d53574d0ddea22d5256eec29c7`; intentionally dirty worktree
- **Environment:** macOS 27 target; Google Chrome user-present UI; Google Cloud project `aura-505908`; temporary local AURA bundle `/tmp/aura-sp011-live/AURA.app`
- **Authority:** The user gave explicit just-in-time approval in this turn to add and save the least-privilege Gmail read scope. That approval did not yet authorize the separate OAuth grant button.
- **Procedure:** In Google Auth Platform > Data Access, entered `https://www.googleapis.com/auth/gmail.readonly`, added it to the scope table, selected the Gmail read row, and saved the data-access changes. The page then showed the Gmail scope with the user-facing description “View your email messages and settings” and the save controls disabled with “Data access changes saved!”.
- **OAuth pre-consent:** Opened the desktop-client authorization flow, selected the approved test-account session from the account chooser, passed the Testing-app warning, and reached the Google permission screen. The screen lists only email-message/settings read access and exposes `Cancel` and `Continue`; `Continue` was **not clicked**. No password, 2FA, client secret, authorization code, access token, refresh token, or TCC/security setting was entered or read.
- **AURA observation:** The exact temporary AURA bundle launched to `Idle / Ready`; Setup reported complete. Source inspection confirmed the current production connection seam accepts externally obtained token material and stores it through the Keychain onboarding boundary; no OAuth connect control is exposed in the current AURA Setup surface.
- **Result:** **Partial live progress; SP-011 remains blocked.** Google scope configuration is now proven, and the OAuth consent surface is ready for a separate just-in-time grant decision. The live Gmail read/thread/injection/offline/revocation matrix, token exchange, Safari extension trust path, and TCC/Contacts/Calendar acceptance remain unproven.
- **Artifact:** This evidence record; no screenshot, token, private message body, or unredacted account data was saved.
- **Evidence class:** Direct user-present Computer Use / external OAuth pre-consent; partial live evidence.
- **Limitations / next action:** A separate user confirmation is required immediately before clicking Google `Continue` (the actual grant). If granted, the flow still needs a safe callback/token-exchange path and AURA enrollment without exposing token material. Do not send mail or mutate calendar/contact data; do not start SP-012.
