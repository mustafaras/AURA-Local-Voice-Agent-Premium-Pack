---
id: SP-024
sequence: 24
track: R10
gap_ids: OPEN-11
depends_on: SP-023
next_prompt: SP-025
state: pending
---

# SP-024 — Network, OAuth, and Injection Enforcement

## Mission

Prove every production network/provider/subprocess path is policy-enforced and externally influenced content remains non-authoritative.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R10 prompt`
- `NetworkEndpointPolicy`
- `URLSession factories`
- `DNS/TLS/proxy paths`
- `OAuth adapters`
- `provenance/injection tests`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-11

## Hard boundaries

- Work only on OPEN-11; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Inventory URLSession, DNS/IP, proxy/TLS, downloads, provider transports, Ollama, subprocess, and extension paths.
2. Route them through mandatory factories with scheme/host/port/path, redirect, body, cookie/cache, DNS, TLS, download, and offline bounds.
3. Complete PKCE/state/callback/account isolation/revocation and redacted leakage corpus across logs/events/env/args/crashes/support.
4. Run web/mail/file/terminal/model tool-spoof and indirect-injection adversarial cases.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-025 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-024`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

No covered network or content path bypasses policy; OAuth and injection evidence passes with no secret leakage.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-024 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-025.
