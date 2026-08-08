# ADR-040 — Browser, Mail, Calendar, and Contacts Integrations: OAuth Scopes and Trust Boundaries

- Status: Accepted
- Date: 2026-08-07
- Owners: GitHub Copilot engineering session
- Supersedes: —
- Superseded by: —

## Context

R5 (`06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md`) requires delivering practical
personal-assistant workflows through structured, least-privilege adapters for browser,
mail, calendar, and contacts. The prompt is explicit about the rollout order and the
safety spine: **read-only capabilities first**; mutations and sending only after
draft/review, bound confirmation, injection defenses, and independent verification are
complete. It also mandates that computer use remain a *fallback*, never the primary
productivity integration, and that page/mail/attachment/event content be treated as
untrusted data.

The codebase already provides the security primitives this track composes over rather
than re-invents:

- **`CapabilityRegistry`/`CapabilityManifest`/`CapabilityPlanner`** (ADR-038) — the sole
  production source of capability contracts; unknown/wrong-version/disabled
  capabilities fail closed at lookup and plan-validation time. `InitialCapabilitySet`
  already registers `filesystem.open_file`, `filesystem.open_folder`,
  `filesystem.reveal`, and `url.open` as truthfully `.disabled` (no adapter yet), and
  `computerUse.run` as `.disabled` until live-validated (ADR-039).
- **`PolicyEngine`** (ADR-006) — deny-by-default capability/grant/confirmation engine
  with `PermissionRiskTier` (`.observation`/`.reversible`/`.mutation`/`.destructive`)
  and immutable `ConfirmationTransaction` (ADR-037) that binds approval to plan hash,
  target, context, nonce, risk, and expiry, and never replays on restart.
- **`KeychainSecretStore`/`SecretStoring`** (ADR-020) — real macOS Keychain generic
  password storage with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (never
  iCloud-synced), a protocol seam so tests never touch the real Keychain, and a
  live-verified add/retrieve/delete round trip (2026-07-26). `Capability.secretStore`/
  `.secretRetrieve`/`.secretDelete` already exist and are policy-gated.
- **`NetworkAllowlist`** (ADR-020) — deny-by-default outbound host allowlist with
  `*.` wildcard semantics, currently with no real non-loopback caller; R5 is the first
  legitimate consumer that needs non-loopback network access.
- **`ContentProvenance`/`PromptInjectionClassifier`** (ADR-020) — type-level authority
  guarantee (only `.systemPolicy`/`.userUtterance` carry authority) plus a
  deterministic, weighted rule classifier that only ever scans non-authoritative
  content. `RISK-INDIRECT-PROMPT-INJECTION` (R4/R5/R10, High/Critical, Open) is exactly
  the threat this track must close for web/mail/event content.
- **`ComputerUseBetaAllowlist`** (ADR-039) — the closed-by-default, `.liveValidated`-only
  allowlist pattern that R5's account/profile scoping should mirror.

The capability matrix records the four R5 capabilities as `missing`/`not_constructed`:
`browser.structured` (mutation tier), `mail.read_draft_send` (destructive tier),
`calendar.events` (mutation tier), `contacts.lookup` (observation tier), plus the
`security.oauth_keychain` dependency (R10, restricted tier). `RISK-MISSING-PRODUCTIVITY-ADAPTERS`
(R5, High/High, Open) and `RISK-OAUTH-OVERPRIVILEGE` (R5/R10, Medium/Critical, Open) are
the two risks this ADR's decisions directly mitigate.

Per the project's "no invented APIs" constraint, this ADR does **not** assume browser or
provider API shapes from memory. The concrete adapter mechanisms (Apple Mail structured
integration, Gmail OAuth scopes, CalendarKit/EventKit, Contacts framework, browser
extension/protocol) must be verified against official current documentation before
implementation, and the ADR records the *decision* and *trust boundaries* now while the
mechanism verification happens at implementation time.

## Decision

1. **Read-first is the default posture; mutation/send is a separately gated, later
   rollout.** Every R5 capability is registered in `CapabilityRegistry` with a
   truthful `CapabilityAvailability`. Read-only capabilities (`browser.read_page`,
   `mail.read`, `calendar.read`, `contacts.lookup`) are `.ready` once their adapter and
   tests exist. Mutation/send capabilities (`mail.draft`, `mail.send`, `calendar.write`,
   `browser.fill_form`, `browser.click`) are registered `.disabled` with a truthful
   reason until their draft/review, bound confirmation, injection defenses, and
   independent verification are complete — mirroring how `computerUse.run` is registered
   `.disabled` until live-validated (ADR-039). A read-only installation must never
   request send scope.

2. **OAuth scopes are incremental and least-privilege, and a read-only installation
   requests only read scopes.** Each provider integration declares a fixed, reviewed
   scope set per capability tier. The read tier requests only read scopes (e.g. Gmail
   `gmail.readonly`, calendar read, contacts read). The compose tier adds draft scopes.
   The send tier adds send scope **only** when the user explicitly opts into send
   authority. Scope escalation is itself a `PolicyEngine.evaluate` decision against a
   dedicated capability (e.g. `Capability.oauthEscalate`), never a silent widening.
   `RISK-OAUTH-OVERPRIVILEGE` is mitigated by making the scope set a reviewed manifest
   field, not a caller-supplied string.

3. **Tokens live only in Keychain references and are immediately revocable.** OAuth
   access/refresh tokens are stored via `SecretStoring`/`KeychainSecretStore` under a
   per-provider, per-account key namespace (mirroring the existing
   `secretKeychainServiceName` namespacing). The token value never appears in an event
   payload, log, prompt, or speech output — matching ADR-020's "no secret value ever
   appears in an event payload" guarantee. Revocation is a first-class operation: a
   `revoke(account:)` path deletes the Keychain reference and, where the provider
   supports it, calls the provider's revocation endpoint. A revoked/expired token
   degrades the capability to `.disabled(reason: "token revoked")` rather than silently
   retrying.

4. **Every provider network call passes through `NetworkAllowlist`.** R5 is the first
   legitimate non-loopback consumer of `NetworkAllowlist` (ADR-020 decision 13 deferred
   retrofitting it onto Ollama because loopback-only is stronger there). Each provider
   adapter is constructed with an explicit allowlist of the provider's API/redirect
   hosts, and redirects/domains are re-checked against that allowlist before any
   request is sent or any redirect followed. This closes the `RISK-NETWORK-ALLOWLIST-INCOMPLETE`
   gap for the R5 path specifically (the general R10 enforcement remains open).

5. **Page, mail, attachment, and event content is untrusted data with provenance
   tagging and content isolation.** Every piece of external content is labeled with a
   `ContentProvenance` value that does **not** carry authority (e.g. `.webContent`,
   `.mailBody`, `.eventContent`), and is passed through `PromptInjectionClassifier`
   before it can influence capability selection, policy, confirmation, recipients, or
   secret requests. Content is isolated from system/tool instructions in the model
   context (a structural separation, not a prompt convention). This directly mitigates
   `RISK-INDIRECT-PROMPT-INJECTION` for the R5 content paths.

6. **Account/profile scope is explicit and closed, mirroring `ComputerUseBetaAllowlist`.**
   Each provider integration operates against an explicit, user-approved account or
   browser profile. Ambiguous accounts (multiple matches) resolve to a clarification
   request, never to a guess. The full address book is never exposed to a model:
   `contacts.lookup` resolves only the candidates needed for the current request and
   clarifies ties. This matches the R5 prompt's "Do not expose the full address book to
   a model" and "account/profile ambiguity" requirements.

7. **Send and mutation flows use a dedicated immutable confirmation transaction.**
   Sending mail, creating/updating/deleting events, and browser mutations that change
   persistent state go through the existing `ConfirmationTransaction` discipline
   (ADR-037): a reviewable draft/plan, a bound confirmation bound to the exact plan
   fingerprint, one-time execution, and post-action verification against the provider's
   returned message/event ID. Authentication, payment, permission, upload, publish,
   delete, and purchase boundaries require confirmation or refusal — never a bare
   `.allow`.

8. **Computer use remains an explicit, bounded fallback, never the primary
   integration.** For each workflow, the integration priority is: (1) native
   framework/provider API; (2) official structured protocol/extension/CLI/Shortcuts
   integration; (3) Accessibility; (4) screen/computer use as explicit fallback. The
   ADR records this priority and requires each selected mechanism to document why it is
   the safest reliable option. AURORA never falls back to browser UI automation for
   account actions without explicit user selection and compatible policy.

9. **Offline/degraded behavior is a first-class, distinguishable state.** Each
   capability reports a distinct degraded reason: integration not configured; token
   expired/revoked; network unavailable; provider unavailable; scope insufficient;
   account ambiguous; content blocked by privacy policy. These map to
   `CapabilityAvailability.degraded(reason:)` so the UI and dialogue can present the
   honest state rather than a generic failure.

## Alternatives considered

- **A model-backed planner/classifier as the first R5 conformer.** Rejected for the
  same reason ADR-039 rejected it for computer use: the local 8B model's structured-output
  sampling variance (`RISK-STRUCTURED-NLU-MODEL-QUALITY`) is a documented, accepted
  bounded risk, and a deterministic read-first adapter keeps the "no raw external text
  becomes an action" guarantee structurally airtight. A model-backed layer can be added
  behind the same adapter boundary later.
- **Storing OAuth tokens in configuration or a plain file.** Rejected — ADR-020 and
  `ConfigurationKeyDefinition.sensitive` already mandate Keychain-only for sensitive
  values; a plain file would violate the established secret boundary.
- **Requesting full provider scopes up front for convenience.** Rejected — this is
  exactly `RISK-OAUTH-OVERPRIVILEGE`; incremental, least-privilege scopes with a
  read-only default are the stated R5 requirement.
- **Exposing the full address book to the model for "better" contact resolution.**
  Rejected — the R5 prompt explicitly forbids it; scoped candidate resolution with
  ambiguity clarification is the privacy-preserving alternative.
- **Using computer use / screen automation as the primary browser integration.**
  Rejected — the R5 prompt explicitly forbids it ("computer use must remain a fallback
  rather than the primary productivity integration"); a structured browser adapter is
  the primary path.
- **A content-shape-only injection classifier for mail/web content.** Rejected — ADR-020
  decision 3 already established that authority comes from provenance, not phrasing;
  R5 reuses `ContentProvenance` + `PromptInjectionClassifier` rather than inventing a
  parallel classifier.

## Security and privacy impact

- External content (web pages, mail bodies, attachments, event descriptions) can never
  carry authority or select capabilities, weaken policy, approve actions, change
  recipients, or request secrets — a type-level guarantee via `ContentProvenance`, plus
  deterministic `PromptInjectionClassifier` scanning of non-authoritative content.
- OAuth tokens are Keychain-only, never in events/logs/prompts/speech, and immediately
  revocable; a read-only installation never holds send scope.
- Network egress is deny-by-default via `NetworkAllowlist` per provider, with redirect
  re-checking — closing the R5 slice of `RISK-NETWORK-ALLOWLIST-INCOMPLETE`.
- The full address book is never exposed to a model; only scoped candidates are
  resolved, with ambiguity clarified.
- Send and mutation flows are bound by immutable confirmation transactions and verified
  against provider-returned IDs; destructive boundaries require confirmation or refusal.
- Computer use is an explicit, bounded fallback, never a universal shortcut around
  missing adapters.

## Operational impact

- `Sources/AuraIntent/InitialCapabilitySet.swift` gains the R5 capability manifests
  (browser/mail/calendar/contacts), registered with truthful availability.
- New adapter targets (e.g. `Sources/AuraProductivity/` or per-domain targets) hold the
  browser/mail/calendar/contacts adapters, an OAuth scope manifest, a per-provider
  `NetworkAllowlist` construction, and the Keychain-backed token store wiring.
- `Sources/AuraCore/PolicyTypes.swift` gains the new `Capability` statics
  (e.g. `browser.readPage`, `mail.read`, `mail.draft`, `mail.send`, `calendar.read`,
  `calendar.write`, `contacts.lookup`, `oauthEscalate`) with appropriate risk tiers.
- New test targets (e.g. `AuraProductivityTests`) cover the required R5 test list:
  OAuth scope escalation/revocation, Keychain reference handling/redaction,
  domain/redirect/network enforcement, account/profile ambiguity, read-only-cannot-mutate,
  draft review and immutable send confirmation, recipient/address ambiguity, attachment
  path/size/type controls, time-zone/recurrence/conflict logic, provider error/retry/
  cancellation, exact post-action verification, mail/web/event prompt injection, secrets
  never entering logs/events/prompts/speech, and computer-use fallback remaining explicit
  and bounded.

## Migration

No breaking migration. The new capabilities and adapters are additive; existing
`InitialCapabilitySet` entries are unchanged. No new database schema — OAuth token
references reuse `KeychainSecretStore` and any persisted state reuses `AuraStore`'s
existing generic key-value store, matching ADR-020/ADR-039 conventions. Existing
`AuraConfiguration` JSON files decode unchanged; missing productivity/oauth keys merge
in their defaults (deny-by-default: empty allowlist, no configured accounts).

## Validation evidence

- Deterministic unit tests for: OAuth scope escalation and revocation; Keychain
  reference handling and redaction (no token in events); domain/redirect/network
  enforcement via `NetworkAllowlist`; account/profile ambiguity; read-only scope cannot
  mutate/send; draft review and immutable send confirmation; recipient/address
  ambiguity; attachment path/size/type controls; time-zone, recurrence, and conflict
  logic; provider error/retry/cancellation; exact post-action verification; mail/web/
  event prompt injection (via `ContentProvenance` + `PromptInjectionClassifier`);
  secrets never entering logs/events/prompts/speech; computer-use fallback remaining
  explicit and bounded.
- Full repository regression (20/20 bundles) re-passed after the additions.
- Live acceptance (with explicitly authorized test accounts/profiles, user physically
  present): summarize unread mail; search and summarize a thread; create but do not send
  a draft; send a benign test message after reviewed confirmation (only if send authority
  is explicitly granted); show tomorrow's agenda and free window; draft/create a test
  event with attendee ambiguity resolution; open and summarize an approved page;
  demonstrate injection content is ignored; revoke access and prove immediate
  disablement.

## Consequences

- **Positive:** R5 gains a least-privilege, read-first, injection-resistant, privacy-visible
  architecture for browser/mail/calendar/contacts, reusing the verified security
  primitives (Keychain, NetworkAllowlist, ContentProvenance, PromptInjectionClassifier,
  ConfirmationTransaction, CapabilityRegistry) rather than inventing parallel ones.
- **Negative:** Live acceptance and any real-account OAuth flow require the user
  physically present with explicitly authorized test accounts; the concrete provider
  mechanisms must be verified against official current documentation at implementation
  time (no API shapes assumed here).
- **Risk:** `RISK-MISSING-PRODUCTIVITY-ADAPTERS` and `RISK-OAUTH-OVERPRIVILEGE` are
  materially mitigated by this ADR's decisions but not closed — the adapters, tests, and
  live acceptance are still required before R5 completion. `RISK-INDIRECT-PROMPT-INJECTION`
  is mitigated for the R5 content paths but the general R10 enforcement remains open.

## Related

- `06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md`
- `docs/decisions/ADR-038-capability-registry-and-planner.md`
- `docs/decisions/ADR-039-production-computer-use-planner.md`
- `docs/decisions/ADR-020-security-hardening.md`
- `docs/decisions/ADR-037-runtime-health-and-confirmation-transactions.md`
- `docs/security/28_PROMPT_INJECTION_DEFENSE.md`
- `docs/security/30_THREAT_MODEL.md`
- `Sources/AuraSecurity/` (`KeychainSecretStore`, `NetworkAllowlist`,
  `PromptInjectionClassifier`, `ContentProvenance`)
- `Sources/AuraIntent/` (`CapabilityRegistry`, `InitialCapabilitySet`)
- `Sources/AuraCore/PolicyTypes.swift`
