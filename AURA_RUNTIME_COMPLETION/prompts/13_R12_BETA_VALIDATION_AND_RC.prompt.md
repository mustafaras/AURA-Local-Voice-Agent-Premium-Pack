# R12 — Beta Validation and Release Candidate Prompt

Execute only after R11 is complete and a clean installable release-candidate artifact exists.

## Mission

Prove that AURA works reliably in realistic daily use. Run a controlled beta, measure defined SLOs, review incidents and false-success cases, complete security/accessibility/privacy sign-off, and prepare an evidence-backed release candidate.

Do not use beta participation or anecdotal success as a substitute for objective gates.

## Required context

Read:

- current state, capability matrix, risk register, evidence index, release gates;
- final SLO definitions in the master plan and accepted ADR-047;
- release artifact and build provenance;
- incident response and security review findings;
- accessibility/localization evidence;
- privacy/telemetry design;
- update/recovery/uninstall evidence;
- all open critical/high risks.

## A. Beta scope and cohort

Define:

- internal vs external beta;
- supported hardware/OS/profile matrix;
- enabled and explicitly excluded capabilities;
- local/cloud model modes;
- data/telemetry consent;
- issue reporting and severity/SLA;
- rollback/kill-switch authority;
- privacy notice;
- duration and minimum sample counts.

Do not expose experimental computer-use, mail-send, wake-word, neural voice, plugins, or remote-agent capabilities unless their specific gates passed.

## B. Privacy-preserving measurements

Collect only opt-in, content-free aggregates needed for:

- crash-free sessions;
- wake/voice activation success;
- STT/intent/dialogue latency and correction rate;
- capability execution and verification success;
- false-success and unknown-outcome rate;
- confirmation/denial/cancellation;
- task recovery;
- memory/thermal/energy pressure;
- update/rollback success;
- permission/integration health.

No raw audio, screenshots, mail, documents, prompts, model outputs, secrets, or private identifiers leave the device by default.

## C. SLO evaluation

Evaluate at minimum:

- Push-to-Talk acknowledgement;
- wake-to-ack if wake is in scope;
- first STT partial and stable transcript latency;
- deterministic command completion;
- local dialogue first token;
- TTS first audio;
- Turkish/English intent and entity accuracy;
- false-success rate;
- destructive action without confirmation: zero;
- secure-field generated input: zero;
- unapproved screen capture: zero;
- crash-free sessions;
- durable task restart recovery;
- update and rollback success.

Report sample size, percentile distribution, hardware, OS, model/engine versions, and exclusions. Do not publish only medians when tails are unsafe.

## D. Scenario matrix

Run structured scenarios covering:

- Turkish, English, and mixed conversation;
- app/file/URL actions;
- browser/mail/calendar read workflows;
- draft/review/confirmed mutation where in scope;
- VS Code/tests/coding agent;
- computer use in approved apps;
- memory/reference resolution;
- permission denial/revocation;
- offline/provider/model/backend unavailable;
- sleep/wake/device change;
- task/app/helper crash and recovery;
- update/rollback/uninstall;
- prompt injection and malicious content;
- emergency stop;
- accessibility and keyboard-only operation.

## E. Incident and failure review

For every severity-1/2 event and every false-success case:

- preserve privacy-safe evidence;
- classify root cause;
- determine blast radius;
- fix or disable capability;
- add regression/adversarial test;
- update risk register;
- verify remediation in a new build;
- record release impact.

No critical unresolved data-loss, unauthorized-action, secret-leakage, privilege, update, or false-success issue may remain.

## F. Independent sign-offs

Obtain documented review for:

- security architecture and open findings;
- privacy/data retention/integrations;
- accessibility and Turkish/English localization;
- release/update/recovery;
- product behavior and truthful messaging;
- support/readiness documentation.

## G. Release-candidate evidence package

Produce:

- exact commit/tag and source provenance;
- signed/notarized artifact hashes;
- SBOM/dependency/model manifests;
- CI/test/coverage/adversarial results;
- clean-install/update/rollback/recovery evidence;
- SLO report;
- beta incident/fix summary;
- open/accepted risks;
- capability scope and exclusions;
- privacy/security/accessibility sign-offs;
- release notes and known limitations;
- rollback/kill-switch plan.

## Completion gate

R12 is complete only when the beta window and sample requirements are met, mandatory SLOs pass, no critical unaccepted risk remains, false-success and unauthorized-action gates pass, reviews are complete, the artifact is reproducible and recoverable, and the release-candidate evidence package is approved by the authorized owner.

Update state to `release_candidate_verified` only if all gates genuinely pass. Otherwise leave R12 blocked/in progress and disable affected capabilities. Accept ADR-047, update all records, mark FINAL ready, and run closeout.
