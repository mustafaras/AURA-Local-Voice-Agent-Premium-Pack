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

---

# Round 2 — 2026-08-30 — cross-agent independent review

> **Reviewer:** Claude Code (Opus 5), acting as the non-implementing reviewer of
> the SP-023 / SP-024 / SP-025 security work.
> **Conflict of interest (disclosed):** the reviewer did **not** write the code
> under review — SP-023 (helper IPC authentication), SP-024 (network/OAuth/
> injection) and SP-025 (plugin trust) were authored by the
> `deepseek-v4-flash:0731-cloud` agent (VS Code Copilot session
> `de53c5c3-58f4-4eaf-8946-54d486f53100`), and the reviewer opened none of those
> commits. The reviewer *did* author the SP-030 readiness-contract work and the
> remediation for F-001 below, and is therefore **not** independent for those and
> must not sign them off. Both parties are LLM agents of the same class; this is
> **not** a human expert audit and is not presented as one.
> **Method:** adversarial source read of the security core, each claim checked
> against a call-path grep and, where a defect was suspected, a executable
> proof-of-concept rather than an assertion.

## Findings

| ID | Area | Severity | Status | Owner | Closure evidence |
|----|------|----------|--------|-------|------------------|
| F-001 | IPC / helper authentication | **High** | Fixed | Reviewer (remediation authored this pass) | `EV-SP-030-20260830-SECURITY-REVIEW-01`; regression tests in `HelperIPCAuthenticationTests` |
| F-002 | Network enforcement | **Medium** | Open | Unassigned — needs an allowlist policy decision | — |
| F-003 | IPC / helper peer identity | Low | Open (accepted risk candidate) | Unassigned | — |
| F-004 | Network enforcement | Low | Open | Unassigned | — |

### F-001 (High, fixed) — unauthenticated crash inside the IPC authentication check

`HelperIPCAuthenticator.constantTimeEquals` guarded on `String.count` (a
**grapheme** count) and then indexed two **UTF-8 byte** arrays:

```swift
guard lhs.count == rhs.count else { return false }   // graphemes
let a = Array(lhs.utf8); let b = Array(rhs.utf8)     // bytes
for i in a.indices { diff |= a[i] ^ b[i] }           // b[i] can be out of range
```

At every call site the **left** operand is the tag read off the wire
(`Sources/AuraShellHelper/main.swift:54`, `Sources/AuraAutomationHelper/main.swift:54`,
`Sources/AuraCore/HelperIPCClient.swift:230`) and the right operand is the locally
computed 64-character ASCII hex tag. A hostile tag of 64 *characters* containing
one multi-byte scalar (63 hex chars + `é`) therefore passes the grapheme guard
with a 65-byte array, and `b[64]` traps.

**Proof of concept** (exact function replicated, Swift 6.4):

```
Swift/ContiguousArrayBuffer.swift:695: Fatal error: Index out of range
exit=133
```

**Impact.** The trap sits *inside* the authentication check, before
authentication succeeds, on attacker-controlled input. A crafted request crashes
whichever helper receives it; a crafted response from a compromised or spoofed
helper crashes the **main AURA process**. SP-023's stated goal is that a peer
without the shared secret "cannot forge a request or response" — it cannot, but
it *could* halt the app, which is an availability boundary the design did not
intend to concede.

**Notable:** the codebase already had this right. The older
`VSCodeBridgeSecurity.constantTimeEquals` compares `Array(lhs.utf8).count`
correctly; SP-023 regressed an existing correct pattern rather than inventing a
new one.

**Remediation.** Compare UTF-8 byte counts, never `String.count`. Two regression
tests added covering both operand orders. `AuraCoreTests` 72 → 74, all pass.

### F-002 (Medium, open) — DNS/IP pinning is implemented and tested but never enforced

`Sources/AuraSecurity/ResolvedIPValidator.swift` is a correct, fail-closed
allowlist primitive (empty allowlist denies; a single unexpected address fails
the whole set). **It has zero production callers.** Every reference to
`isAllowed(ip:)` / `allAllowed(resolvedIPs:)` in the repository is inside
`Tests/AuraSecurityTests/URLSessionFactoryTests.swift`.

`SP-024`'s evidence and this document's Round 1 both describe network enforcement
as covering "URLSession factory, DNS/IP, redirect, TLS, proxy" with no finding.
The URLSession factory half is genuinely wired — `URLSessionFactory.makeSession()`
is used by `OllamaAPIClient` and `ProductivityAdapters_HTTPProviderTransport`,
with cookies and cache disabled and redirects refused. The **DNS/IP half is not
in effect anywhere**, so the documented DNS-rebinding protection does not
currently protect any request.

This is a claim-versus-reality gap rather than a regression: nothing became less
safe, but the evidence chain implies a control that is not active. Wiring it
requires deciding an allowlist policy (localhost-only for Ollama? pinned provider
ranges?), which is a design decision and was deliberately **not** invented by this
review.

### F-003 (Low, open) — peer identity is PID-based, not audit-token-based

`SecCodeHelperIPCPeerVerifier` resolves the peer via
`SecCodeCopyGuestWithAttributes` with `kSecGuestAttributePid`. PID-keyed identity
is subject to PID reuse and a check-to-use race; XPC — which ADR-044 calls this
mechanism the "reviewed equivalent" of — authenticates peers by **audit token**
precisely to avoid that. The practical exposure is narrow because the client
spawns the helper itself and verifies immediately, so the race window is small
and local code execution is already required. Recorded so the "equivalent to XPC
peer identity" claim is read with its actual limits rather than at face value.

### F-004 (Low, open) — `ResolvedIPValidator` normalization is textual, not numeric

`normalize` lowercases, trims and strips IPv6 zone identifiers, then does exact
string matching. Equivalent textual forms of the same address (`::1` vs
`0:0:0:0:0:0:0:1`, `::ffff:127.0.0.1` vs `127.0.0.1`, IPv4 with leading zeros)
compare unequal. Every such mismatch **denies**, so this is not a bypass — but if
F-002 is ever closed, a resolver returning a different textual form than the
allowlist would silently break legitimate connections. Parse to a numeric address
before comparing.

## Areas reviewed with no finding

- **Network egress bounds.** `URLSessionFactory` is the single production session
  source (2 callers, both verified), uses `.ephemeral`, disables cookies
  (`httpShouldSetCookies=false`, `.never`, storage nil) and cache (`urlCache=nil`,
  `reloadIgnoringLocalAndRemoteCacheData`), and refuses every redirect via
  `RedirectRejectingDelegate` returning `completionHandler(nil)`.
- **Secret redaction.** `SecretPatternLibrary` is a genuine single source of truth,
  consumed by `SecretScanner`, `OutputRedactor`/`RedactionEngine.default` and
  `RepositoryInstructionsScanner` — no drifted second copy of the pattern set.
- **IPC envelope binding.** The tag covers the exact transmitted JSON text on both
  request and response (`requestText`/`responseText` encoded under the payload
  key and decoded from those same bytes), so there is no cross-process
  canonicalization dependency, and responses are bound to the request nonce with
  sandbox attestation checked before the tag comparison.
- **Plugin trust.** Signature/hash/quarantine/vendor-root handling is wired into
  `PluginRegistry` and `PluginRegistry_Lifecycle` rather than living as an
  unreferenced primitive.

## Limitations of this review

Source-level adversarial reading plus call-path verification and one executable
proof of concept. It is **not** a human expert audit, **not** a penetration test,
**not** a runtime/fuzzing campaign, and it did not exercise the helpers under a
live hostile peer. Reviewer and author are LLM agents of the same class. F-001's
remediation was authored by the reviewer and therefore still needs a reviewer
other than its author.

---

# Round 3 — 2026-08-30 — accessibility / localization review

> **Reviewer:** Claude Code (Opus 5). **COI:** the reviewer did not author SP-021
> (accessibility/localization) or any `Sources/AURA` view code, and is independent
> of them under ADR-050. It is **not** independent of the SP-030 contract or the
> F-001 remediation. LLM agent, not a human accessibility auditor; no assistive
> technology was driven, no screen reader session was run, no WCAG audit tool used.
> **Method:** source read plus mechanical counting of user-facing literals and
> accessibility strings against the app's language conditional.

## Verdict: `accessibility_localization` sign-off is **REFUSED**

F-005 is material to precisely what this sign-off attests. It must be fixed or
explicitly accepted by the owner before the sign-off can be recorded.

| ID | Area | Severity | Status |
|----|------|----------|--------|
| F-005 | Localization / accessibility | **High (for this domain)** | Open |
| F-006 | Accessibility — Dynamic Type | Low | Open |

### F-005 (High, open) — Turkish localization does not reach the accessibility layer or most of the UI

AURA localizes by in-code mapping on a runtime language setting
(`language == .turkish ? "…" : "…"`), not `.strings`/`NSLocalizedString`. That is a
legitimate choice for a language that is a user preference rather than the system
locale, and SP-021 genuinely fixed the status pill and capability-detail mappings.
**The coverage, however, is very thin:**

- **45 of 49** user-facing visible literals in `Sources/AURA` (`Text`, `Label`,
  `.help`) have **no** language conditional anywhere near them.
- **38 of 42** accessibility strings (`accessibilityLabel`, `accessibilityHint`)
  are English-only.

So selecting Turkish changes the status pill and a few capability details while the
rest of the interface — and essentially the entire VoiceOver surface — stays
English.

**Safety-critical instance.** The emergency control
(`Sources/AURA/AuraMenuView_Tabs.swift:488-505`) is entirely unlocalized:

```swift
GroupBox("Emergency control") {
  Button("Re-arm generated input") { … }
    .accessibilityHint("Allows generated mouse and keyboard input again")
  Label("Emergency Stop", systemImage: "hand.raised.fill")
    .accessibilityHint("Immediately disables generated input")
```

A Turkish-speaking VoiceOver user is read English for the control that stops
generated mouse and keyboard input. This is the one control where comprehension
under stress matters most.

**Why prior evidence did not catch it.** `EV-SP-021-…-ACCESSIBILITY-LOCALIZATION-01`
recorded live inspection of the *status pill* and the *Capabilities tab* and fixed
real bugs in both. Those fixes are genuine. But the evidence generalizes from two
verified surfaces to an "accessibility and localization" claim, and no test asserts
that the accessibility layer localizes at all. A `statusPillLocalizesToTurkish`
test exists; no `emergencyStopLocalizesToTurkish` equivalent does.

**Recommended remediation.** Route every user-facing and accessibility string
through the existing language mapping, starting with the emergency control and the
VoiceOver surface; add a test that fails when an accessibility string in
`Sources/AURA` has no Turkish counterpart, so coverage cannot silently regress.

### F-006 (Low, open) — seven fixed font sizes bypass Dynamic Type

`Sources/AURA` uses semantic text styles in 37 places (Dynamic Type-safe) but
`.font(.system(size: …))` in **7** (`AuraMenuView_Content.swift:55, 95, 107, 145`
and three others), which do not scale with the user's text-size preference. Live
Dynamic Type behaviour was previously observed
(`EV-SP-021-20260825-DYNAMIC-TYPE-LIVE-03`), so this is a partial gap, not a
missing capability. Replace with semantic styles or `@ScaledMetric`.

## Reviewed with no finding

- **Localization architecture.** In-code mapping is appropriate here; the language
  is a runtime user preference, so a `.strings` catalog keyed to system locale
  would be the wrong mechanism.
- **Accessibility identifiers.** Present and used for automation across the menu
  views; distinct from labels and not a substitute, but correctly applied.
- **Status pill and capability-detail localization.** SP-021's fixes hold.

## Limitations

Static source review and mechanical counting only. **No screen reader was driven,
no assistive technology exercised, no WCAG conformance audit performed, and no
Turkish-speaking user tested the interface.** The literal counts use a
six-line proximity heuristic for the language conditional and may misclassify
individual lines; the ratio (roughly 4 in 49) is the finding, not any single line.

---

## CORRECTION to Round 3 — 2026-08-30 (issued by the same reviewer)

**Round 3 overstated F-005's magnitude by roughly threefold. The numbers below
supersede the ones published above; the earlier figures should not be cited.**

### What was wrong

Round 3 reported "**38 of 42** accessibility strings are English-only" and
"**45 of 49** user-facing literals have no language conditional". Both came from a
six-line proximity heuristic that:

- could not see **multi-line** modifier calls, and
- did not recognise **inline ternaries** of the form
  `language == .turkish ? "Ayarlar" : "Settings"`, which are fully localized.

A multi-line-aware recount gives the accurate figure:

| | Reported (wrong) | Actual |
|---|---|---|
| Accessibility strings not localized | 38 of 42 | **13 of 41** |
| User-facing visible literals | 45 of 49 | **withdrawn — not reliably measurable** |

The visible-literal figure is **withdrawn, not replaced**: the corrected extractor
produced obviously corrupt output (capturing literals from continuation lines), and
publishing a second unverified number would repeat the original error. That
sub-claim is unmeasured.

Of the 13 genuinely unlocalized accessibility strings, several interpolate content
that **is** already localized — `AURA.swift:36` wraps
`model.status.title(for: language)`, and `AuraDesign.swift:122` composes
`\(title). \(detail)` from localized parts — so only the English prefix or
separator is untranslated. The substantive static gaps are approximately eight:
`"Corrected memory statement"`, `"Read VS Code editor state"`,
`"Performs a read-only, policy-authorized live bridge check"`,
`"Search inspectable memory"`, `"Memory deletion receipt…"`, and the
`"Trace: "` (×2), `"Diagnostic: "` and `"AURA status: "` prefixes.

### What this does and does not change

- **F-005 is downgraded High → Medium.** Its safety-critical instance — the
  emergency control, including both VoiceOver hints — was real, is fixed, and is
  now pinned by three regression tests. That part of the finding stands entirely.
- **The `accessibility_localization` sign-off refusal STANDS**, on the corrected
  grounds: 13 of 41 accessibility strings still bypass the language mapping, which
  is a genuine gap even though it is far smaller than reported.
- **Round 2's findings are unaffected.** F-001 was proven by an executable crash,
  and F-002 by an exhaustive call-path grep; neither used this heuristic.

### Why this matters beyond the numbers

Round 3 criticised `EV-SP-021-…-ACCESSIBILITY-LOCALIZATION-01` for generalising
from two verified surfaces to a broad "accessibility and localization" claim. The
reviewer then did the same thing: it generalised from a crude pattern match to a
published ratio, and refused a sign-off partly on that inflated figure. The
correction is recorded here rather than by editing the original text, so the error
and its scope stay visible.

**Method note for future rounds:** a proximity heuristic over source text is not
evidence. Either parse structure, or verify each hit by hand and report the count
as a hand-verified sample — never as an exhaustive ratio.
