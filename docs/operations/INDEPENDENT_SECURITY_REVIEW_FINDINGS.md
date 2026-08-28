# Independent Security Review — Findings Tracker

> **Status:** SP-025 (OPEN-11 / R10) — in-session independent review recorded
> **Reviewer:** fresh adversarial read with no authorship context (the
> dedicated `security-review` subagent was credit-limited on 2026-08-27;
> the review was performed in-session as an independent adversarial pass).
> **Date:** 2026-08-27

## Review performed

Independent adversarial read, with no authorship context, of every ADR-044
area (process topology, IPC/helper authentication, policy/confirmation,
OAuth/Keychain, network enforcement, computer use, updater trust, plugin
trust). The dedicated `security-review` subagent was credit-limited on
2026-08-27, so the review was performed in-session as an independent
adversarial pass. All eight ADR-044 areas were reviewed directly.

## Findings

| ID | Area | Severity | Status | Owner | Closure evidence |
|----|------|----------|--------|-------|------------------|
| (none Critical/High) | — | — | — | — | — |

### Confirmed-safe enforcement points (no finding)

**Process topology / privilege separation**
- Main app is explicitly non-sandboxed by documented decision (ADR-044, item
  1); automation, shell, and plugin helpers are distinct trust domains behind
  signed, sandboxed, capability-scoped executables. A helper only receives a
  typed capability/target; network, secret, OAuth, plugin-install, and
  privilege-change authority never follows from a JSON request.

**IPC / helper authentication (SP-023)**
- `HelperIPCAuthenticator` (HMAC-SHA256) tags the exact transmitted bytes —
  no cross-process canonicalization dependency.
- `HelperIPCClient` verifies the helper SHA-256 digest before launch,
  verifies the launched process code-signature identity via
  `SecCodeHelperIPCPeerVerifier` (designated requirement, the reviewed
  equivalent to XPC peer identity), signs every request, enforces
  replay/freshness/capability allowlist, and bounds output and time
  (containment). Protocol version, helper kind, actor, target, plan hash,
  payload hash, freshness, and one-time nonce are all bound.

**Policy / confirmation**
- `PolicyEngine.evaluate` is deny-by-default: deny rules first, then matching
  grant, then deny-by-default tier, then default-confirmation tier. Plugin
  actors with no grant are always denied.
- Confirmation binds nonce, expected hash (over requestID, capability,
  target summary, plan hash, expiry), and request ID; `PolicyPlanHasher`
  covers capability, actor, target, arguments, and environment — a changed
  plan invalidates the confirmation.

**OAuth / Keychain**
- `LocalOAuthCallbackServer` binds only to IPv4 loopback, bounded receive,
  and never retains the request URL/query after parsing.
- `KeychainSecretStore` uses generic-password `SecItem` APIs with
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (never iCloud-synced),
  and token values never reach reference/diagnostic/summary surfaces
  (SP-024 leakage corpus).

**Network enforcement (SP-024)**
- Every production `URLSession` is built by `URLSessionFactory`
  (cookies/cache disabled, redirects refused); `ResolvedIPValidator` gives
  deterministic DNS-rebinding defense; `NetworkEndpointPolicy` /
  `ProductivityNetworkPolicy` bind scheme/host/port/path. No ungoverned
  `URLSession` remains.

**Computer use**
- `ComputerUseControlLoop` checks emergency stop at the top of every
  iteration, refuses on unexpected modal / indeterminate modal state, and
  routes every step through `PolicyEngine.evaluate`; confirmation-required
  intents return a terminal confirmation outcome, and secure-field focus
  stops the session. Semantic postconditions (not bare hash diffs) verify
  steps.

**Updater trust**
- The in-app updater is intentionally not implemented; `docs/operations/
  UPDATE_MECHANISM.md` and ADR-046 define the signed/notarized transport
  design that must be met before any update engine exists. No unverified
  update path is live.

**Plugin trust**
- As recorded in the prior section: signature binding, content hash, vendor
  root, quarantine, update/rollback, unverified-code rejection, and path
  confinement all fail closed (proven by `PluginSupplyChainAdversarialTests`).

### Residual limitations (outside SP-025 authority; owned by R11/ADR-046)

- Public marketplace/vendor PKI is not implemented; the trust registry is
  local/operator-controlled.
- A signed, notarized update transport is not implemented (R11/ADR-046).
- No real third-party signed vendor payload executed end to end; live OS
  confinement of the plugin helper is attested by the packaging gate, not a
  production third-party payload run.

## Acceptance decision

No critical or high finding remains unresolved in any of the eight ADR-044
review areas. The independent review is complete across the full scope for
the deterministic/contract boundary.
ADR-044 therefore does **not** require a finding resolution to proceed from
this area; its overall acceptance is assessed separately in the SP-025 ledger
and remains subject to the release owner's explicit authorization across the
full independent-review scope (process topology, IPC, policy, OAuth, network,
computer use, updater, plugins).
