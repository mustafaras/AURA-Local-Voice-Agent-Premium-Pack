# EV-SP-011-20260818-OAUTH-RETRY-06

- **Evidence ID:** `EV-SP-011-20260818-OAUTH-RETRY-06`
- **Prompt / gap:** SP-011 / OPEN-06 (R5 live acceptance)
- **Timestamp:** 2026-08-18T17:50:03Z (20:50:03 Europe/Istanbul)
- **Session:** `AURA-SP-011-COMPUTER-UI-OAUTH-RETRY-20260818`
- **Actor:** Codex, under the user's explicit instruction to retry the timed-out Continue flow
- **Branch / commit:** `main` / `33688e2a54f1e5d53574d0ddea22d5256eec29c7` (`origin/main` matched; worktree intentionally dirty)
- **Evidence class:** Direct user-present Computer Use / provider redirect partial live evidence

## Objective

Retry the approved least-privilege Google OAuth flow for SP-011 without reading,
copying, recording, or exposing authorization codes, access tokens, refresh
tokens, passwords, 2FA codes, or client secrets, then determine whether AURA can
enter the live read-first acceptance matrix.

## Procedure and result

1. Reopened the Google OAuth flow in Google Chrome with a fresh retry state and
   the previously approved `gmail.readonly` scope.
2. The provider flow reached the local redirect endpoint
   `127.0.0.1:48080/oauth2callback` with the read-only scope and a provider
   authorization result. The browser then displayed `ERR_CONNECTION_REFUSED`.
3. No authorization code or token material was copied, parsed, logged, or
   passed to a remote service by this session. No Gmail message, thread, draft,
   calendar event, contact, or other private provider data was opened.
4. The temporary production bundle remained alive as the exact process
   `/private/tmp/aura-sp011-live/AURA.app/Contents/MacOS/AURA` (PID 14636), but
   no process was listening on TCP port 48080 at the time of verification.
5. Source inspection confirms the repository has an OAuth token/session type
   and `AuraKernel.connectMailAccount(accountID:accessToken:...)`, but no live
   `oauth2callback`/48080 listener, URL callback handler, token exchange, or
   user-facing OAuth enrollment control. The AURA Setup UI showed setup complete
   but no OAuth connect action.

## Acceptance verdict

The retry proves only the provider-side redirect and the local callback failure.
It does **not** prove OAuth enrollment, live Gmail reads/thread summaries,
revocation, Safari native messaging, TCC/Contacts/Calendar prompts, or any R5
matrix item. SP-011 remains **blocked** and SP-012 is not safe to start.

## Safety and scope boundary

- Mutation/send was not attempted.
- No permission mutation, Safari extension install, commit, push, merge,
  release, or deployment was performed.
- Adding a callback server, token exchange, or enrollment UI would be a separate
  product/runtime feature and was not silently implemented under this live
  acceptance prompt.

## Falsifier and next safe action

A separately authorized implementation of a fail-closed OAuth callback and
enrollment path, followed by a user-present run that captures the full R5
read-first matrix and revocation, would falsify this blocked conclusion. Until
that path exists, keep SP-011 blocked and do not start SP-012.

## Cleanup

After the observation, the exact temporary AURA PID 14636 was terminated and
verified absent. The callback tab's address was then replaced with
`about:blank`; no browser credentials or provider data were modified.
