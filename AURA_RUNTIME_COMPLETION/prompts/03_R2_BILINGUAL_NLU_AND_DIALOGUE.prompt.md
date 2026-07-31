# R2 — Bilingual NLU and Dialogue Prompt

Execute only after R1 is complete and the production turn/orchestration contracts are stable.

## Mission

Make AURA understand natural Turkish, English, and Turkish–English code-switching through voice and text. Replace the fixed conversation acknowledgement with a real, local-first dialogue engine while preserving typed boundaries, provenance, policy, and safe clarification.

## Required context

Read:

- intent engine, typed intent, dispatcher, and current classifier tests;
- Ollama adapter, model registry, structured-output implementation, and tests;
- context builder/reference resolver/memory interfaces;
- conversation and response-plan contracts;
- runtime health and `TurnContext` from R1;
- ADR-036 proposal and current model/security decisions.

## Required design

### A. Layered NLU

Implement three layers:

1. **Deterministic bilingual fast path** for high-frequency commands, emergency commands, and known safe local actions.
2. **Local structured NLU** using a schema-validated local model for natural instructions not resolved by the fast path.
3. **Clarification/slot-filling dialogue** when confidence, target, account, time, file, application, task, or action is ambiguous.

Do not use model confidence as authority. Unknown capability IDs, malformed arguments, or unsupported targets must be rejected.

### B. Language routing

Support:

- Turkish;
- English;
- mixed utterances with technical terms, app names, code, paths, and repository language;
- locale-preserving responses;
- explicit user language preference;
- per-turn language detection with deterministic override.

Create a golden corpus with natural variants, not only command templates.

### C. Structured output

Define a closed NLU result including:

- dialogue act: answer, execute, clarify, confirm, delegate, cancel;
- language;
- proposed capability ID;
- typed arguments;
- references/entities;
- confidence and ambiguity reasons;
- context requirements;
- risk hints that are recomputed by policy/capability metadata rather than trusted.

Validate every local-model response. Add retry/repair only within a strict bounded budget. Fall back to clarification or deterministic behavior; never guess an executable plan.

### D. Dialogue engine

Implement a typed dialogue engine that can:

- answer ordinary questions through the selected local reasoning backend;
- summarize provided/approved context;
- explain a proposed action;
- ask concise clarification questions;
- maintain pending slots and references across turns;
- report unavailable model/degraded mode honestly;
- produce separate visual detail and TTS-safe concise text.

The model receives minimal context with provenance, capability summaries, policy constraints, language, and response budget. It does not receive secrets or unredacted private content.

### E. Replace canned conversation

Remove or deprecate the production `Got it.` placeholder. Deterministic acknowledgements remain acceptable only for explicit low-latency commands where no substantive answer is requested.

### F. Context use

Connect context reconstruction to dialogue without allowing memory or retrieved content to authorize action. Include source IDs and confidence. Handle contradictions explicitly.

## Initial bilingual fast-path scope

At minimum:

- stop/cancel/pause/resume;
- open/activate/quit known application;
- task status;
- run a registered coding agent;
- open a known file/folder/URL capability when R3 registers it;
- ask a general question;
- repeat/rephrase;
- approve/deny a pending confirmation using an unambiguous bound interaction.

Use aliases and generated app/entity registries rather than a fixed eight-app dictionary.

## Testing and evaluation

Required:

- Turkish/English/mixed golden intent corpus;
- paraphrase, morphology, punctuation, casing, and ASR-error variants;
- technical terms, paths, names, repositories, and code-switching;
- schema-malformed and unknown-capability model responses;
- prompt-injection content treated as data;
- ambiguous destructive references always clarify;
- multi-turn slot filling and expiry;
- pending confirmation approve/deny cannot bind to another action;
- model unavailable/degraded behavior;
- context token-budget enforcement;
- no secret in model prompt, log, event, or speech;
- general questions return substantive model-backed answers.

Measure intent accuracy, entity/slot accuracy, clarification rate, model structured-output validity, first-token latency, and user-language consistency.

## Completion demonstration

On authorized hardware:

1. ask a general question in Turkish;
2. ask a general question in English;
3. issue a mixed-language technical command;
4. use a paraphrased application command;
5. create one ambiguous request and observe clarification;
6. disable/unavailable the local model and observe honest degradation;
7. inspect the trace and context provenance.

## Completion gate

R2 is complete only when:

- the production dialogue path is model-backed and typed;
- Turkish, English, and mixed input meet the defined evaluation target;
- fast path remains deterministic and safe;
- ambiguity produces clarification, not guessed execution;
- local model failures degrade honestly;
- context is bounded and provenance-aware;
- no raw model result reaches execution;
- R3 can consume a stable NLU/dialogue contract.

Accept ADR-036, update capability/evidence/risk/state/ledger/handoff, mark R3 ready, and run closeout.
