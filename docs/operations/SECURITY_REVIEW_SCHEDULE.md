# Security Review Schedule

> **Owner:** Independent security reviewer, rotated every quarter.  
> **Scope:** All code, configuration, and documentation that affects AURA's safety boundaries, privacy posture, or trust model.

## Cadence

| Review | Frequency | Duration | Output |
|--------|-----------|----------|--------|
| Adversarial harness review | Every release | 4 hours | Signed ledger entry noting harness coverage and gaps |
| Full threat-model review | Quarterly | 1 day | Updated `docs/security/30_THREAT_MODEL.md` residual-risk register |
| Dependency / supply-chain audit | Quarterly | 4 hours | Updated `docs/security/26_SUPPLY_CHAIN.md` findings |
| Permission and entitlements review | Per release | 2 hours | Diff of `*.entitlements`, `Info.plist`, sandbox profile |
| Ad-hoc red team | On demand | Variable | Git issue + playbook entry |

## Independence rule

The engineer who wrote the feature under review must not be the sole reviewer. The reviewer must not have opened the PRs being reviewed. Reviewers document conflicts of interest in the ledger entry.

## Review checklist

1. **Authority boundaries.** Every untrusted input path has `ContentProvenance.carriesAuthority == false` and a corresponding deterministic guard (classifier, policy, or router).
2. **Destructive actions.** No destructive capability is reachable without confirmation or deny-rule block in `AuraAdversarialTests`.
3. **Confirmation binding.** `PolicyConfirmationChallenge.expectedHash` is derived from request fields; `submitConfirmation` verifies hash and expiry.
4. **Memory provenance.** `MemoryProvenance` / `ContextAuthority` ranks user-stated above inferred; `ReferenceResolver` blocks weak evidence for destructive targets.
5. **Supply chain.** `PluginVerifier` rejects unsigned, tampered, vendor-swapped, or forged packages; no test invents a notarization chain.
6. **Configuration.** `ConfigurationEngine` rejects patches that weaken security, privacy, or resource constraints.
7. **Privacy.** No ambient audio, screenshots, documents, or keystrokes leave the device unless an explicit user-controlled setting enables a bounded export.
8. **Observability.** Logs and events contain useful diagnostic context without secrets or PII.

## Evidence retention

- Each review produces a dated entry in `ledger/PROJECT_LEDGER.md`.
- Findings are tracked as Git issues with the `security-review` label.
- Closed findings must be accompanied by a regression test in `AuraAdversarialTests` or the relevant subsystem tests.

## Next scheduled review

See `ledger/CURRENT_STATE.md` for the date and owner of the next scheduled review.
