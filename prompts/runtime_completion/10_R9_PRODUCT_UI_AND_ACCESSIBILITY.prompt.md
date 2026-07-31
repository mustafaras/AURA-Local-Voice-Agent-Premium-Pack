# R9 — Product UI, Accessibility, and Onboarding Prompt

Execute after R4, R5, R6, R7, and R8 are complete or explicitly scoped out with truthful disabled states.

## Mission

Transform the existing menu-bar control panel into a coherent assistant product. All primary workflows must be visible, understandable, keyboard-operable, VoiceOver-compatible, localized, privacy-transparent, and usable without terminal intervention.

## Required context

Read:

- `Sources/AURA`;
- runtime health, dialogue, task, capability, confirmation, model, memory, integration, and evidence interfaces;
- existing UI tests/permission onboarding;
- Apple HIG, accessibility, localization, and ServiceManagement UI guidance relevant to the supported SDK;
- active risks and release gates.

Do not change backend contracts casually from the UI layer. Fix contract defects in their owning modules with tests.

## Required information architecture

### A. Conversation

Provide:

- text input fallback;
- Push to Talk/wake/privacy controls;
- live partial and final transcript;
- assistant response;
- clarification and confirmation cards;
- plan/progress/verification summary;
- stop/cancel/retry;
- expandable evidence and diagnostics;
- privacy/local-vs-cloud indicator.

### B. Task Center

Show:

- queued, running, paused, awaiting input/confirmation, verifying, completed, failed, cancelled;
- objective, backend/model, workspace/account/app scope;
- budgets and elapsed time;
- latest progress;
- cancel/resume/retry;
- diff/tests/artifacts/evidence;
- truthful verification state.

### C. Capability and permission center

Show:

- installed capabilities and status;
- required permissions/dependencies/accounts/models;
- local/cloud classification;
- risk/confirmation behavior;
- active grants and expiry;
- revoke/disable/test capability;
- disabled/degraded reason.

### D. Model and voice center

Show:

- STT, NLU/reasoning, TTS, coding models;
- installed/available/loaded/disabled/degraded;
- language/capability support;
- memory/resource estimate;
- current routing/fallback chain;
- benchmark/health;
- model download/remove under explicit authority;
- reference-voice consent status.

### E. Privacy, memory, and integrations

Provide:

- local-only/cloud mode;
- active microphone/screen indicators;
- recent approved observations/actions;
- diagnostic retention controls;
- memory inspect/correct/delete/export;
- browser/mail/calendar account scopes and revoke;
- network activity summary;
- grants and confirmations history.

### F. Recovery and diagnostics

Provide:

- permission repair guidance;
- dependency/model health;
- safe mode;
- reset grants/memory/cache where allowed;
- support bundle generation;
- update status;
- uninstall guidance;
- no secret/private content in support bundles.

## Onboarding

Build a staged onboarding flow:

1. product privacy/local-vs-cloud explanation;
2. system compatibility and health check;
3. microphone and STT permission only;
4. microphone/STT test;
5. TTS/voice selection test;
6. explain and optionally enable wake word;
7. explain and optionally enable Accessibility/Screen Recording;
8. configure local model;
9. configure optional browser/mail/calendar integrations and scopes;
10. emergency stop demonstration;
11. guided safe command;
12. launch-at-login choice when R11 implements it.

Request permissions only when the user enables the relevant capability.

## Accessibility and localization

Required:

- full keyboard navigation;
- logical VoiceOver reading order;
- meaningful labels/hints/status announcements;
- focus management for confirmation/error/progress;
- contrast and non-color state cues;
- scalable text/layout;
- reduced motion where applicable;
- Turkish and English localization;
- locale-aware dates/times/numbers;
- no critical action dependent on hover or gesture only.

## Error and degraded design

Every failure must state:

- what failed;
- whether anything changed;
- whether outcome is known;
- how to recover;
- whether retry is safe;
- where evidence/details are available.

Never show an unavailable capability as selectable without its disabled reason.

## Tests

Required:

- view-model/state reducer tests;
- confirmation focus and expiry;
- task progress and verification states;
- permission/dependency/model degraded states;
- privacy indicator correctness;
- secret redaction;
- keyboard navigation;
- VoiceOver labels/order via automated checks plus manual review;
- localization completeness and layout;
- Dynamic Type/scaled text;
- onboarding branches and permission denial;
- restart state restoration;
- emergency stop visibility and operation;
- support bundle privacy.

## Live acceptance

Conduct a structured usability/accessibility pass in Turkish and English on clean and configured profiles. Include VoiceOver, keyboard-only, permission denied/revoked, no model, offline, task failure, confirmation, and recovery scenarios.

## Completion gate

R9 is complete only when primary workflows are accessible through polished UI, users can understand and control permissions/privacy/models/memory/tasks, degraded states are actionable, onboarding is staged, Turkish/English localization is complete, and manual accessibility evidence exists.

Update program records and unblock R11 after R10 is also complete. Run closeout.
