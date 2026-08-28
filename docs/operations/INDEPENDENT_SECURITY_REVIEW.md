# Independent Security Review Plan

> **Status:** SP-025 (OPEN-11 / R10) — review plan and findings tracker
> **Owner:** Independent security reviewer (rotated quarterly, distinct from
> feature author)

## Purpose

Record how AURA obtains and tracks the independent architecture/security
review that ADR-044 and R10 require before release. This is the *plan and
findings tracker*; completion of the review itself is a separate, evidence
gated event.

## Review scope (per R10 and ADR-044)

The independent review must cover:

- process / privilege topology and helper trust domains;
- IPC / helper authentication (peer identity, replay, capability allowlists);
- policy / confirmation binding;
- OAuth / Keychain handling and secret-leak surfaces;
- network enforcement (URLSession factory, DNS/IP, redirect, TLS, proxy);
- computer use (allowlist, secure-field, emergency stop);
- updater trust (R11/ADR-046);
- plugin trust (vendor roots, signatures, hashes, quarantine, rollback,
  unverified-code rejection, helper integrity).

## Independence rule

The engineer who wrote the feature under review must not be the sole reviewer.
The reviewer must not have opened the PRs being reviewed. Reviewers document
conflicts of interest in the ledger entry.

## Cadence

| Review | Frequency | Duration | Output |
|--------|-----------|----------|--------|
| Adversarial harness / plugin trust review | Every release | 4 hours | Signed ledger entry noting coverage and gaps |
| Full threat-model review | Quarterly | 1 day | Updated `docs/security/30_THREAT_MODEL.md` residual-risk register |
| Dependency / supply-chain audit | Quarterly | 4 hours | Updated `docs/security/26_SUPPLY_CHAIN.md` findings |
| Permission / entitlements review | Per release | 2 hours | Diff of `*.entitlements`, `Info.plist`, sandbox profile |
| Ad-hoc red team | On demand | Variable | Git issue + playbook entry |

## Findings tracker

Findings are tracked as Git issues with the `security-review` label. Each
finding records severity, owner, reproduction, fix, regression test, and
closure status. Closed findings require a regression test in
`AuraAdversarialTests` or the relevant subsystem tests.

| ID | Area | Severity | Status | Owner | Closure evidence |
|----|------|----------|--------|-------|------------------|
| (opened under SP-025) | — | — | — | — | — |

## Evidence retention

Each review produces a dated entry in `ledger/PROJECT_LEDGER.md` and
`AURA_RUNTIME_COMPLETION/state/EVIDENCE_INDEX.md`. Keep reproducer inputs in
test files; never commit ambient audio, screenshots, secrets, or user
documents. Store non-public details in the project keychain or secure vault.

## Release gate

ADR-044 must remain Proposed until the independent review covers every area in
the scope table and no critical unaccepted finding remains. A finding is
"accepted" only with explicit release-owner authorization, a scope, and an
expiry — never silently.
