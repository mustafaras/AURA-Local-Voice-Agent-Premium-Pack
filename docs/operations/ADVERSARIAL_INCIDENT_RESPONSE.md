# Adversarial Incident Response Playbook

> **Owner:** Security lead (rotating, independent of current feature author).  
> **Applies to:** Any red-team, external report, internal audit, or CI failure that surfaces a new adversarial bypass, weakness, or regression in AURA's safety boundaries.

## Goal

Turn every adversarial finding into a reproducible regression test, a documented fix, and an append-only ledger entry without disrupting the real-time audio path or leaking private data.

## Severity levels

| Level | Criteria | Examples | Response time |
|-------|----------|----------|---------------|
| **Critical** | Immediate harm possible without user confirmation; bypass of destructive/capability policy. | Tool router allows destructive shell without confirmation; plugin install bypasses signature check. | 4 hours |
| **High** | Privilege escalation or data-exfiltration path with some user interaction. | Policy grant with `.none` confirmation can be widened to destructive tier; prompt-injection causes auto-approve. | 24 hours |
| **Medium** | Defense evasion, information disclosure, or circumvention of non-destructive guardrail. | Non-English injection not blocked; zero-width payload evades classifier at medium severity. | 7 days |
| **Low** | Documentation gap, monitoring blind spot, or test coverage hole. | Missing residual-risk entry; ops playbook out of date. | Next sprint |

## Response flow

1. **Contain.** Reproduce the finding with a deterministic, local test case in `Tests/AuraAdversarialTests/`. Do not use production user data, live audio, or remote services.
2. **Triage.** Assign severity, owner, and a Git issue/ledger entry. If critical, pause releases until fixed.
3. **Fix.** Change production code or configuration defaults. Do not weaken unrelated guardrails for convenience.
4. **Regression-test.** Add the reproducer to `AuraAdversarialTests` and run `./scripts/aura-test.sh`.
5. **Document.** Update the relevant ADR residual-risk section or add a new risk to `Sources/AuraCore/ResidualRiskRegistry.swift`.
6. **Ledger.** Append evidence to `ledger/PROJECT_LEDGER.md` and update `ledger/CURRENT_STATE.md`.
7. **Review.** Independent security reviewer verifies the fix, test, and ledger entry before merge.

## Evidence retention

- Keep reproducer inputs in the test file; never commit ambient audio, screenshots, or user documents.
- Redact any tokens, keys, or PII from fixture text before committing.
- Store non-public details in the project keychain or secure vault, not in repository files or logs.

## Contacts and escalation

- Primary: security lead (see `docs/security/30_THREAT_MODEL.md`).
- Engineering: agent orchestration engineer for multi-agent/capability issues, real-time audio engineer for VAD/wake-word issues, macOS systems engineer for permission/signing issues.
- External reports: coordinate with project lead before any public disclosure.
