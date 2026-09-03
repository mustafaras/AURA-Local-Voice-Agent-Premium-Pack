# Agent Operating Contract


> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


All coding agents working in this repository must follow this contract.

## Required startup sequence

Before editing:

1. Read `README.md`.
2. Read `ledger/CURRENT_STATE.md`.
3. Read `ledger/PROJECT_LEDGER.md`.
4. Read the specification relevant to the task.
5. Inspect the current repository and tests.
6. State the objective, assumptions, risks, and acceptance criteria in the task ledger.
7. Confirm that the proposed work does not conflict with an existing architectural decision.

## Non-negotiable behavior

- Never fabricate framework methods, package capabilities, command flags, file paths, or test results.
- Verify unstable APIs from official documentation or installed tool help.
- Never claim success unless the relevant commands were actually executed and their outputs inspected.
- Never delete or rewrite ledger history.
- Never bypass the permission engine for convenience.
- Never send raw ambient audio or unredacted screenshots to a remote service without an explicit user-controlled setting.
- Never place secrets in source code, logs, prompts, fixtures, crash reports, or ledger entries.
- Never use UI automation when a reliable native or structured integration exists.
- Never mix unrelated refactors into a feature change.
- Never silently change architecture, security policy, data schema, or supported OS baseline.

## Required completion sequence

1. Run formatting, static analysis, unit tests, integration tests, and relevant end-to-end tests.
2. Review the diff for accidental scope expansion.
3. Update documentation and migration notes.
4. Append an evidence-backed entry to `ledger/PROJECT_LEDGER.md`.
5. Update `ledger/CURRENT_STATE.md` atomically.
6. Record unresolved risks and the next safe action.
7. Do not commit, push, release, or deploy unless the task explicitly authorizes it.

## Definition of done

A task is done only when:
- acceptance criteria are met;
- failure modes are handled;
- tests prove the intended behavior;
- logs contain useful diagnostic context without private content;
- permissions remain least-privilege;
- state survives restart where required;
- ledger and documentation are current.

## Archived runtime-completion surface (2026-09-03)

The former `AURA_RUNTIME_COMPLETION/` execution surface (the second-pass prompt
chain: `SP-000`–`SP-033`) is **complete and archived**. It is preserved
under `archive/runtime-completion/` (git history and tracking intact, 298 files)
so the runtime/second-pass/beta validators and the ledger/evidence/decision/
risk history continue to resolve.

- Do **not** start a new `SP-*` prompt; `next_prompt` is `none` and the chain is
  closed under `docs/decisions/ADR-053-live-evidence-synthetic-scope.md`.
- Re-point any in-repo reference from `AURA_RUNTIME_COMPLETION/…` to
  `archive/runtime-completion/…` (or treat it as frozen history).
- Re-opening requires a new ADR (see ADR-049/ADR-053), not a file edit.
