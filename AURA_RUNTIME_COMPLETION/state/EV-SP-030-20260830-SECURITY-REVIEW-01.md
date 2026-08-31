# EV-SP-030-20260830-SECURITY-REVIEW-01

**Evidence ID:** EV-SP-030-20260830-SECURITY-REVIEW-01
**Track:** SP-030 / R12 / OPEN-13 (independent sign-off path) + OPEN-11 / R10 (ADR-044 review areas)
**Type:** Independent review (cross-agent) + High-severity defect remediation
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty, uncommitted)
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, Python 3.14.6
**Session:** AURA-SP-030-BETA-EVIDENCE-20260830

## Independence and conflict of interest (disclosed)

**Reviewer:** Claude Code (Opus 5). **Authored by a different agent:** SP-023
(helper IPC authentication), SP-024 (network/OAuth/injection), SP-025 (plugin
trust) were written by `deepseek-v4-flash:0731-cloud` in VS Code Copilot session
`de53c5c3-58f4-4eaf-8946-54d486f53100`. The reviewer opened none of those commits
and is therefore independent of them under
`docs/operations/INDEPENDENT_SECURITY_REVIEW.md`'s independence rule.

**The reviewer is NOT independent of:** the SP-030 readiness-contract work and the
F-001 remediation below, both authored by the reviewer this session. Those require
a different reviewer and are excluded from any sign-off the reviewer supports.

Both parties are LLM agents of the same class. **This is not a human expert audit,
not a penetration test, and not a fuzzing campaign**, and must never be recorded as
one. The governing model is ADR-050 (**Proposed** — until the owner accepts it,
this review supports no sign-off).

## Method

Adversarial source read of the security core, with every claim checked against a
call-path grep, and — where a defect was suspected — an executable proof of
concept instead of an assertion.

## Result: 1 High (fixed), 1 Medium (open), 2 Low (open)

### F-001 — High, **fixed this pass**: unauthenticated crash inside the IPC authentication check

`HelperIPCAuthenticator.constantTimeEquals` guarded on `String.count` (grapheme
count) and then indexed two UTF-8 **byte** arrays. At all three call sites the left
operand is the tag read off the wire. A hostile 64-*character* tag containing one
multi-byte scalar passes the grapheme guard with a 65-byte array, and the loop
indexes the 64-byte side out of range.

Proof of concept (exact function, Swift 6.4):
`Swift/ContiguousArrayBuffer.swift:695: Fatal error: Index out of range`, exit 133.

Impact: the trap is *inside* the authentication check, before authentication
succeeds, on attacker-controlled input. A crafted request crashes the receiving
helper; a crafted response from a compromised or spoofed helper crashes the **main
AURA process**. SP-023's goal — an unauthenticated peer "cannot forge a request or
response" — held, but such a peer could halt the app.

The codebase already had this correct: `VSCodeBridgeSecurity.constantTimeEquals`
compares UTF-8 byte counts properly. SP-023 regressed an existing correct pattern.

**Remediation (authored by the reviewer):** compare UTF-8 byte counts, never
`String.count`; two regression tests covering both operand orders.

### F-002 — Medium, **open**: DNS/IP pinning implemented, tested, never enforced

`ResolvedIPValidator` is a correct fail-closed allowlist primitive with **zero
production callers** — every `isAllowed(ip:)` / `allAllowed(resolvedIPs:)`
reference is in `Tests/AuraSecurityTests/URLSessionFactoryTests.swift`. SP-024's
evidence and Round 1 of the independent review both describe network enforcement
as covering "DNS/IP" with no finding; that control is not active on any request.
The `URLSessionFactory` half **is** genuinely wired (2 production callers).

Not a regression, but a claim-versus-reality gap. Closing it requires an allowlist
policy decision, which this review deliberately did **not** invent.

### F-003 — Low, open: peer identity is PID-based, not audit-token-based
`SecCodeHelperIPCPeerVerifier` uses `kSecGuestAttributePid`; XPC — which ADR-044
calls this the "reviewed equivalent" of — uses audit tokens to avoid PID reuse and
check-to-use races. Narrow in practice (the client spawns the helper and verifies
immediately), but the equivalence claim is stronger than the mechanism.

### F-004 — Low, open: `ResolvedIPValidator` normalization is textual, not numeric
Equivalent textual forms of one address compare unequal. Every mismatch denies, so
not a bypass — but it would silently break legitimate connections if F-002 closes.

## Reviewed with no finding

Network egress bounds (`URLSessionFactory`: ephemeral, cookies off, cache off,
redirects refused, 2 verified callers); secret redaction (`SecretPatternLibrary` a
genuine single source of truth across `SecretScanner`, `OutputRedactor`,
`RepositoryInstructionsScanner` — no drifted copy); IPC envelope binding (tag over
exact transmitted bytes, response bound to request nonce, sandbox attestation
checked before tag comparison); plugin trust wired into `PluginRegistry` and
`PluginRegistry_Lifecycle`.

## Verification

Full suite after the fix: **1292 tests / 80 suites / 22 bundles — 0 failures**
(`Done. Failed bundles: 0`); `AuraCoreTests` 72 → 74.

## Falsifiers

Any claim that this was a human, external, or third-party audit; that F-002/F-003/
F-004 were closed rather than recorded open; that the reviewer is independent of
the SP-030 contract work or the F-001 remediation; or that any sign-off is obtained
while ADR-050 remains `Proposed`, would falsify this record.

## Net effect on SP-030

**No sign-off is recorded as obtained.** ADR-050 is `Proposed`; until the release
owner accepts it, the independence model that would let this review support the
`security` / `privacy` / `accessibility_localization` sign-offs is not in force.
SP-030 stays `in_progress`. F-002 remains an open Medium that any future `security`
sign-off must either close or explicitly accept.
