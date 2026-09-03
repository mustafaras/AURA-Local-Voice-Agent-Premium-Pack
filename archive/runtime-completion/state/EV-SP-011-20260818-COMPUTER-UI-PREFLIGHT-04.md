# EV-SP-011-20260818-COMPUTER-UI-PREFLIGHT-04

## Scope

- **Prompt:** `SP-011_PRODUCTIVITY_LIVE_ACCEPTANCE` / `OPEN-06`
- **Timestamp:** `2026-08-18T12:40:45Z`
- **Branch / HEAD:** `main` / `33688e2a54f1e5d53574d0ddea22d5256eec29c7`
- **Evidence class:** user-present Computer Use preflight; read-only external configuration inspection
- **Authority:** current user instruction authorized Computer Use navigation and live acceptance work. No password, 2FA, CAPTCHA, OAuth grant, credential, TCC mutation, extension installation, message send, commit, push, merge, release, or deployment was performed.

## Observed UI facts

1. Chrome was already authenticated to the user's Google account. Google Cloud project `aura-505908` was reachable.
2. A Desktop OAuth client named `aura` exists in the project and the OAuth audience is in Testing mode with one existing test user.
3. Gmail API is listed among the project's enabled APIs.
4. Google Auth Platform Data Access currently has no configured scopes. The required `gmail.readonly` scope was not entered or saved because that would expand persistent access and requires just-in-time user confirmation.
5. Safari's current OAuth page reports `redirect_uri_mismatch`. Safari Extensions shows only the built-in Add Extensions entry; no AURA extension is installed or enabled.
6. The exact temporary AURA bundle at `/tmp/aura-sp011-live/AURA.app` reached `Starting. Starting local services` but did not reach a ready state during the bounded UI observation. The temporary process was stopped afterward. A separate stale `/Applications/AURA.app` instance had previously displayed a persisted-grant decode error; no grant or user data was deleted or rewritten.

## Acceptance verdict

SP-011 remains **blocked**. The Google project/client/API prerequisites are partially present, but the read-first matrix and revocation gate still lack a saved read-only scope, user-approved OAuth token, live provider reads, live Safari trust/native messaging, and user-present TCC/Contacts/Calendar evidence. No mutation/send path was attempted.

## Next safe action

Ask the user for explicit just-in-time confirmation immediately before adding and saving `https://www.googleapis.com/auth/gmail.readonly` in the `aura-505908` project's Data Access page. After that, the user must complete any Google login/consent or 2FA handoff, and the Safari extension/trust and TCC prompts must be handled in their presence. Retry only SP-011; do not start SP-012.
