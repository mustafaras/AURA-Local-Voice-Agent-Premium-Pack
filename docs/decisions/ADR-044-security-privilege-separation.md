# ADR-044 — Security and Privilege Separation

**Status:** Proposed
**Date:** 2026-08-09
**Owner:** AURA security/release owner

## Context

AURA has a non-sandboxed main application because the current composition root
still contains audio, Accessibility, screen, shell, local-model, and provider
integration paths. Plugin execution is already moved behind the signed,
sandboxed `AuraPluginHost`, while the automation and shell helper products are
currently typed echo/attestation surfaces rather than complete production
executors. The R10 objective is to reduce blast radius without claiming that
application policy is equivalent to an OS sandbox.

## Proposed decisions

1. The main application remains explicitly non-sandboxed until each privileged
   path has a separately packaged helper and a user-tested recovery path. Its
   entitlements and limitations remain documented in `Resources/AURA.entitlements`.
2. Automation, shell/agent, and plugin helpers are distinct trust domains. A
   helper may receive only a typed capability and target allowed for its helper
   kind; network, secret, OAuth, plugin-install, and privilege-change authority
   never follows from a JSON request.
3. The current process-launch pipe is treated as a parent-launched transport,
   not as a claim of XPC peer authentication. Requests therefore require
   protocol version, helper kind, actor, target, immutable policy-plan hash,
   payload hash, freshness, and nonce replay protection. OS-authenticated XPC
   or an equivalent signed local channel remains a completion gate.
4. All concrete network clients must use an endpoint policy binding scheme,
   host, effective port, and path. Redirects are rejected or revalidated; the
   current Ollama client rejects redirects and allows only the configured
   loopback host family and API path. DNS/IP pinning and provider transports
   remain open until a concrete resolver/client boundary exists.
5. OAuth state/PKCE, reviewed scope manifests, account-scoped Keychain
   references, expiry, and revocation are mandatory. Token values are never
   allowed in arguments, environment, logs, events, prompts, crash reports, or
   support bundles.
6. External content remains data-only. Provenance, schema validation,
   redaction, capability allowlists, and action-time policy re-evaluation are
   required before any externally influenced value can reach an adapter.
7. Plugin verification remains deny-by-default and requires the existing
   manifest signature, vendor trust, payload hash, quarantine, and helper
   attestation path. Public marketplace/catalog PKI and signed update evidence
   are not implied by the local fixture tests.

## Consequences

- Some capabilities remain visibly degraded or disabled until their helper,
  network, account, and live acceptance gates are evidenced.
- A successful local fake/helper test proves a contract, not OS confinement or
  external-beta readiness.
- ADR-044 must remain Proposed until independent review covers process topology,
  IPC authentication, policy/confirmation, OAuth/Keychain, network enforcement,
  computer use, updater trust, and plugin trust.

## Evidence and open gates

The first R10 slice is recorded under `EV-R10-20260809-BOUNDARY-SLICE-01`.
The helper envelope and endpoint policy are source/contract-tested; the
following remain open: production helper wiring, peer-authenticated XPC or
equivalent, DNS/IP revalidation, concrete provider HTTP clients, full OAuth
callback/token exchange, secret-leak corpus across every support/crash path,
independent review, and release-owner acceptance.
