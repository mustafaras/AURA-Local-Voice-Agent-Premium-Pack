# AURA Runtime Completion — Active Context

> **Program:** AURA Runtime Completion Program v1.0.0  
> **Current prompt:** `R1`
> **Current program state:** In progress; R1 ready
> **Audited baseline:** `62f96da3c14b1def80764a259377638142876ccc`

## Canonical status

The strict BOOTSTRAP preflight and R0 governance repair are complete. Canonical machine state is in
`AURA_RUNTIME_COMPLETION/state/current-state.json`; the ordered manifest has
15 implementation prompts and `15_SESSION_CLOSEOUT.prompt.md` remains the
mandatory out-of-manifest session procedure. Legacy status prose is historical
compatibility context and is guarded by the R0 validator. R1 now owns runtime
integration and trace correctness.

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

Run `AURA_RUNTIME_COMPLETION/prompts/02_R1_RUNTIME_INTEGRATION_SPINE.prompt.md`.

The first action is to inspect AuraKernel/AuraAppModel, event envelopes, conversation, intent/dispatch, ToolRouter, policy/confirmation, automation/shell/task interfaces, persistence, and ADRs 021/022/034/035/037 before editing. Do not start Phase 26 or any optional historical roadmap phase merely because older prose names it as the next action.

## Current major risks

- stale contradictory status prose;
- services constructed but not user-reachable;
- fixed `Got it.` conversation behavior;
- English-only narrow intent grammar;
- confirmation/resume semantics not unified;
- broken event correlation/truthful latency metadata;
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
