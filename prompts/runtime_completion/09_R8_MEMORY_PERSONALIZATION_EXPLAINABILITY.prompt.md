# R8 — Memory, Personalization, and Explainability Prompt

Execute after R2 and R3.

## Mission

Activate the existing memory/provenance/context foundations as a useful, user-controlled product capability. Memory must improve dialogue and tool selection without becoming an opaque authority source, privacy sink, or unbounded context store.

## Required context

Read:

- `Sources/AuraMemory`, `Sources/AuraContext`, `Sources/AuraStore`;
- intent/dialogue/capability contracts from R2–R3;
- provenance and context ADRs 016/017/026/027;
- privacy, retention, audit, and configuration code;
- direct memory/context/store tests;
- ADR-043 proposal.

## A. Memory policy

Define explicit write rules by class:

- ephemeral turn state;
- working conversation;
- session summary;
- durable task state;
- project fact/decision;
- user preference;
- procedural knowledge;
- audit/security record.

Persist only information that is:

- explicitly stated and appropriate to remember;
- required for an active durable task;
- derived from verified tool evidence;
- summarized with provenance, confidence, sensitivity, scope, retention, and purpose.

Do not automatically store full mail, pages, attachments, screenshots, transcripts, documents, secrets, or model output.

## B. Context contract

Create a bounded `ContextBundle` containing:

- purpose and requesting component;
- selected memory/evidence records;
- source/provenance IDs;
- authority classification;
- confidence and freshness;
- sensitivity and redaction state;
- token/word budget;
- exclusions and unresolved contradictions;
- explanation for inclusion.

The context builder must rank by scope, recency, authority, evidence, confidence, and task relevance. Content does not gain authority merely by being remembered.

## C. Reference resolution

Support references such as:

- “that repo”;
- “the last file”;
- “the previous test”;
- “ask Claude to review it”;
- “send that draft.”

Resolve only when evidence and conversational salience are sufficient. Destructive or externally consequential targets require direct evidence or clarification.

## D. Contradictions and supersession

- never silently overwrite facts;
- record conflict/supersession edges;
- select active belief according to accepted authority/freshness rules;
- surface tied or material conflicts to the user;
- preserve history while excluding superseded facts from active context.

## E. User preference profile

Add user-controlled settings for:

- preferred language and response length;
- default browser/mail/calendar account;
- coding backend/model preference;
- working directories/projects;
- voice and activation preference;
- local-only/cloud-allowed mode;
- quiet hours;
- memory categories and retention.

Preferences cannot weaken policy, privacy, confirmation, or risk tiers.

## F. User controls and explainability

Expose APIs and later R9 UI for:

- search/browse memory;
- “why was this included?” provenance;
- correct/supersede;
- delete/forget eligible records;
- export;
- retention and project scope;
- inspect active context for a turn;
- revoke preference and clear session/task context.

Audit/security records follow their legal/security retention rules and cannot be silently deleted.

## G. Model/context safety

- sanitize untrusted content;
- never inject memory as system/user authority unless provenance explicitly permits it;
- prevent memory poisoning from web/mail/document/model output;
- enforce context budget;
- avoid secrets/private content in model calls;
- separate local and remote model context policies.

## Tests

Required:

- memory class write policy;
- evidence/provenance required for derived facts;
- retention/expiry;
- correction/supersession/deletion/export;
- contradiction ranking and tied conflict;
- cross-session retrieval;
- project/task/user scope isolation;
- reference ambiguity and destructive-target guard;
- context token budget and deterministic ordering;
- untrusted content/memory poisoning;
- preference cannot weaken security;
- remote model receives only permitted context;
- restart and migration integrity.

## Live/product acceptance

Demonstrate:

1. explicit preference remembered across restart;
2. project fact derived from verified tool evidence;
3. multi-turn reference resolution;
4. ambiguous destructive reference clarification;
5. contradiction surfaced and resolved;
6. memory inspection/correction/deletion/export;
7. context provenance shown for a response;
8. local-only mode excludes remote context transmission.

## Completion gate

R8 is complete only when memory materially improves production dialogue/tools, all active context is bounded and explainable, user controls work, contradictions are safe, poisoning tests pass, and no memory record can silently authorize a risky action.

Accept ADR-043, update capability/evidence/risk/state/ledger/handoff, unblock R9, and run closeout.
