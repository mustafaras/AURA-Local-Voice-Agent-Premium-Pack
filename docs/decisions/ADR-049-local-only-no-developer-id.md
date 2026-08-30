# ADR-049 — Local-Only Distribution: Developer ID and Notarization Permanently Out of Scope

- **Status:** Accepted
- **Date:** 2026-08-30
- **Owners:** AURA Runtime Completion Program / release owner (user)
- **Scope:** R11 release engineering, R12 beta/RC, all distribution decisions

## Context

The release owner (user) decided that AURA is a **local-only product** and will
**never acquire or use a Developer ID certificate or Apple notarization**. The
previous SP-027 local-only scope decision recorded the same intent; this ADR
makes it permanent and updates the normative documents that (until now) still
described Developer ID signing and notarization as a required or re-openable
release prerequisite. The user's instruction (Turkish): *"developer id
almayacağız ve kullanmayacağız"* ("we will not acquire or use Developer ID").

## Decision

1. **AURA is distributed local-only.** There will be no external/public
   distribution via the Mac App Store, Developer ID-signed download, or any
   notarized channel.
2. **Developer ID signing and notarization are permanently out of scope.** The
   project will not obtain an Apple Developer Program membership or a Developer
   ID Application certificate, and will not submit anything for notarization.
3. **The local signing identity (`AURA Stable Local Signing` / ad-hoc
   fallback) is the only signing mechanism.** It is a local, non-distributable
   identity and is never represented as Developer ID, notarized, or public
   distribution trust.
4. **Release-class labels are redefined for the local-only product:** a
   local-only product does not require a "Developer ID + notarized + clean
   external machine" artifact. The honest release evidence is the local
   nested-signing procedure (validated under `EV-SP-027-20260828-SIGNING-PROCEDURE-02`),
   local Gatekeeper behaviour, artifact hashes, and launch evidence.
5. **The artifact keeps the `development_unverified` label** until an owner
   decision + ADR-047/SP-031 produce a provenance-bound RC evidence package for
   the local-only scope. This label is **not** "Developer ID release".
6. **No re-open of these gates** is implied by any "external distribution would
   re-open later" wording. They are closed by this permanent scope decision.

## Consequences

- `RISK-NOT-NOTARIZED` is **Accepted (permanent)** for the local-only scope.
- Normative documents that previously named Developer ID/notarization/clean
  external machine as required or re-openable were updated to reflect this
  permanent decision (TOOLCHAIN, toolchain-manifest, ADR-045, ADR-046,
  operations docs, release gates, gap register, R11 closure plan).
- External distribution, if ever considered later for a genuinely different
  product/audience, would be a **new decision under a new ADR**, not a re-open
  of this scope.
- Historical (append-only) ledger and evidence wording that mentioned Developer
  ID as a prior requirement remains unchanged and is not falsified; this ADR
  supersedes the forward-looking requirement wording in active documents only.

## Review

This is a permanent owner-instructed scope decision. It does not expire; a
future change of distribution intent requires a new ADR and explicit owner
authority.
