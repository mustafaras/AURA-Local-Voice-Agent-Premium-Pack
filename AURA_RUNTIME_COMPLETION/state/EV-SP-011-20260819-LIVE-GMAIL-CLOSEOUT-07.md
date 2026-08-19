# EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07

## Record

- **Prompt / gap:** SP-011 / OPEN-06 (R5 productivity live acceptance)
- **Timestamp:** 2026-08-19T08:08:02Z
- **Branch / commit:** `main`; `HEAD == origin/main == 33688e2a54f1e5d53574d0ddea22d5256eec29c7`
- **Working tree:** `dirty_expected`; the existing SP-010/SP-011 source, test, and control-plane changes were preserved. No reset, clean, checkout, commit, push, merge, release, or deployment occurred.
- **Environment:** macOS 27 beta on Apple Silicon; user-present Computer Use session; approved Gmail test account; least-privilege `gmail.readonly` scope; temporary local development build.
- **Evidence class:** direct user-present provider/UI/store/process evidence plus deterministic source-side regression.

## Objective, assumptions, risks, and acceptance criteria

- **Objective:** repair the missing Gmail OAuth callback/enrollment path, then run the authorized Gmail portion of SP-011: live read/thread summary, injection refusal, offline handling, account ambiguity, credential/provider revocation, and immediate post-revocation disablement.
- **Assumptions:** the approved account and externally provisioned OAuth client are test resources; fixture messages are disposable; mutation/send remains outside AURA and is used only for separately authorized fixture provisioning.
- **Risks:** OAuth material or private message content leaking to output/evidence; an ambiguous request contacting a provider; an injection fixture influencing instructions; offline failure being mislabeled as credential failure; revocation leaving either a Keychain credential or Google grant active.
- **Acceptance criteria:** loopback PKCE callback and token exchange complete without exposing material; a controlled two-message thread is summarized without address/body leakage; adversarial content is blocked; offline and two-account ambiguity fail closed before unsafe output/provider work; local credential and provider grant are removed; a post-revocation read is disabled immediately.
- **Architecture check:** the change stays inside the existing `AuraProductivity` onboarding, `ProductivityRuntime`, `ProductivityReadBridge`, typed intent/router, Keychain, and existing SwiftUI integration surfaces. It does not add a parallel router, broaden Gmail scope, or add AURA send/mutation capability.

## Symptom and root cause

The earlier live OAuth attempt reached the loopback redirect but no AURA listener existed, so the provider callback was refused and no credential could be enrolled. The runtime also lacked the complete typed thread-summary route needed by the live matrix. The affected layer was the R5 provider-onboarding and intent-to-productivity composition path, not the provider account itself.

The repair adds a bounded loopback PKCE callback, state validation, token exchange, approved-account probe, Keychain-only enrollment, typed thread-summary routing, redacted errors, and explicit UI connect/revoke actions. A desktop client secret, where required by the provider, is accepted only from the process environment and is never placed in the authorization URL, repository, logs, events, or evidence.

## Direct live procedure and result

1. Started Gmail read-only authorization from AURA. The loopback callback completed, the provider token exchange succeeded, the approved account was probed, and the credential crossed only the Keychain onboarding boundary. AURA projected the integration as connected and ready.
2. Provisioned, under separate exact user approval, one controlled clean two-message thread and one controlled injection fixture through Gmail's own UI. This was test-data setup, not an AURA mutation/send capability.
3. Ran AURA's typed clean-thread summary. The returned summary was bound to one thread with `messageCount = 2`; no email-like account identifier or raw fixture body appeared. Safe response-state digest: `c96bdc6ef102`.
4. Ran the adversarial thread request. The bridge returned `privacyBlocked = true`; the controlled body did not leak and no email-like identifier appeared. Safe response-state digest: `05d363c877f9`.
5. Forced the live provider transport offline. The result classified `network_unavailable = true` and `credential_error = false`; no private output was produced.
6. Configured two approved account identifiers for the ambiguity leg. AURA returned a clarification before provider contact and emitted no private account content.
7. Moved both controlled fixtures to Gmail Trash. Searches excluding Trash returned no fixture result rows. Trash was not emptied, so cleanup is recoverable.
8. Revoked the local credential without reading token bytes: Keychain state changed from `PRESENT` to `ABSENT`. The Computer Use bridge repeatedly closed when the SwiftUI Privacy tab was selected, so this local deletion used the same Keychain backend as the product revoke path rather than claiming an unobserved button click.
9. Removed the AURA provider grant from Google Account connections and reloaded the connections page; the application was no longer listed.
10. Relaunched AURA after revocation. The integration showed disconnected/Connect Gmail, and a mail-read attempt failed before provider execution with `accessDisabled = true`, no provider result, and no email content. Safe response-state digest: `e57795734eb0`.
11. Closed all local OAuth callback tabs, stopped the diagnostic process, cleared the clipboard, and cleared all SP-011 acceptance environment variables.

## Deterministic verification

- Focused SP-011/SP-010 suites: Gmail OAuth 7, provider/account 24, routing 18, composition 20, R9 UI 7 — **76/76 passed**.
- `./scripts/aura-test.sh /tmp/aura-sp011-final-20260819` — **21/21 bundles, 1023/1023 tests, 0 failed**; `AuraProductivityTests` **55/55**.
- `python3 scripts/validate_second_pass_program.py` — passed after final record synchronization.
- `python3 scripts/validate_runtime_completion.py --ci` — passed after final record synchronization.
- `python3 scripts/validate_repo_hygiene_program.py` — passed after final record synchronization.
- `python3 scripts/validate_repo_hygiene_supply_chain.py` — passed after final record synchronization; six exact test fixtures allowed, zero unallowlisted findings.
- `python3 -m unittest discover -s scripts/tests -p 'test_*.py'` — **38/38 passed** after final record synchronization.
- `git diff --check` — passed.
- Secret-literal pattern scan over the worktree — no candidate client-secret literal found.

## Artifact

- Test-build executable: `/tmp/aura-sp011-final-20260819/out/Products/Debug/AURA`
- SHA-256: `083d171455f88d14a21cfe00fe60c5b520c823ccc71ba9e1253c6587a6094de0`
- Classification: temporary source-parity regression artifact, **not** a signed/notarized/release artifact.

## Falsifier

This result is falsified if any token, authorization code, client secret, account identifier, or fixture body appears in a product/ledger output; if the clean thread is not bound to exactly two messages; if injected text reaches instructions or output; if offline is classified as a credential failure; if an ambiguous account request reaches the provider; if a revoked read produces a provider result; if the local Keychain item remains; or if the Google connection remains listed after reload.

## Scope, limitations, and verdict

- **Gmail/OAuth subset:** passed live. The earlier callback/enrollment blocker, real-account configuration risk, Gmail read/thread/injection/offline/ambiguity legs, and two-sided revocation postcondition are resolved by this evidence.
- **Mutation/send:** explicitly excluded from AURA. Gmail UI sends were separately authorized fixture setup only. The product still has no compose/send mutation path or immutable-send-confirmation evidence.
- **Direct Privacy-tab click:** not observed because selecting that SwiftUI tab closed the Computer Use native pipe. The security postcondition is nevertheless directly evidenced by Keychain absence, provider-side grant removal, disconnected UI, and post-revoke fail-closed read. This UI automation limitation remains recorded.
- **Diagnostic bundle:** a separate diagnostic app was used during troubleshooting and is not source-parity or a release artifact; it was stopped and is not cited as acceptance evidence.
- **Formatting:** repository-wide strict formatting remains blocked by pre-existing `Package.swift` and `SP005CapabilityReachabilityTests.swift` debt. No whole-tree formatter mutation was performed.
- **Canonical SP-011 verdict:** **blocked, not completed.** The prompt also requires live approved-page/Safari native messaging, agenda/free-window, event-draft, and relevant Calendar/Contacts permission evidence. Those legs were not executed. SP-012 is therefore not safe to start.
- **Next safe action:** keep this exact prompt active; run only the remaining Safari approved-page and Calendar/Contacts live legs with user-present trust/TCC interaction, then exercise the product's direct Privacy-tab revoke control if the Computer Use/SwiftUI bridge can remain attached. Do not start SP-012.
