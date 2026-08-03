# AURA Runtime Completion — Active Context

> **Program:** AURA Runtime Completion Program v1.0.0  
> **Current prompt:** `R2`
> **Current program state:** In progress; R1 completed, R2 in progress
> **Audited baseline:** `f1f3bb959ea3b79eb821c5faccf57d8fad076203`

## Canonical status

The strict BOOTSTRAP preflight and R0 governance repair are complete. Canonical machine state is in
`AURA_RUNTIME_COMPLETION/state/current-state.json`; the ordered manifest has
15 implementation prompts and `15_SESSION_CLOSEOUT.prompt.md` remains the
mandatory out-of-manifest session procedure. Legacy status prose is historical
compatibility context and is guarded by the R0 validator. R1 runtime
integration and trace correctness are complete for local development/integration
scope. R2 now owns bilingual NLU and dialogue.

R1 evidence: fresh 20-bundle Swift regression passed 678/678 tests. R2 has now
started with validated bilingual fast-path, typed dialogue, structured-NLU
boundary, locale-preserving response-plan changes, clarification expiry, and
dialogue health. The current-tree regression passes 20/20 bundles and 695/695
tests. Accepted
decisions are ADR-035 (TurnContext trace correctness) and ADR-037 (runtime
health and confirmation transactions). The worktree is intentionally local and
uncommitted; release claims remain blocked by toolchain, live hardware,
privilege, signing, and beta gates.

## Why this program exists

AURA contains many implemented and tested subsystems, but they do not yet form one complete assistant. The primary deficit is integration and product truthfulness, not raw code volume.

The immediate program must:

1. repair repository/state truth;
2. create one correlated production orchestration spine;
3. connect bilingual NLU and real model-backed dialogue;
4. replace the closed five-intent router with a typed capability registry;
5. productize computer use;
6. add structured browser, mail, calendar, and contacts workflows;
7. complete VS Code and coding-agent product paths;
8. add real wake/STT/TTS routing and resource governance;
9. activate memory and explainability;
10. build the full assistant UI;
11. separate privileges and enforce network/secret boundaries;
12. create signed, notarized, updateable distribution;
13. prove beta reliability and final acceptance.

## Immediate next action

With explicit authorization, run a bounded local Ollama health/first-token
benchmark for `gemma4:latest` under the 16 GB memory budget, then perform the
required Turkish, English, mixed, clarification, and degraded-mode hardware
demonstration. Keep R2 in progress until that evidence exists. Do not start
Phase 26 or any optional historical roadmap phase merely because older prose
names it as the next action.

## Current major risks

- live-model/hardware proof for the bilingual path;
- no durable confirmation checkpoint/resume after restart;
- universal capability-specific postcondition verification is incomplete;
- no production computer-use planner;
- VS Code policy not enforced in the adapter path;
- no browser/mail/calendar/contacts adapters;
- no real wake word;
- model memory/thermal contention on 16 GB hardware;
- main-process privilege concentration;
- no Developer ID notarized release or signed updater;
- no independent beta evidence.

## Compact success definition

AURA is complete only when a clean target Mac can install and run a bilingual assistant that understands natural speech/text, answers through a real reasoning backend, executes registered capabilities through policy and bound confirmation, verifies results, handles practical desktop/productivity/coding workflows, exposes memory/privacy/health controls, survives restart/update/recovery, and passes release and beta gates without false-success claims.
