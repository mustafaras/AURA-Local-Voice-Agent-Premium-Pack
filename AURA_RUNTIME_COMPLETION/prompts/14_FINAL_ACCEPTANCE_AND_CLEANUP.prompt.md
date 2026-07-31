# FINAL — Acceptance, Cleanup, and Operational Handoff Prompt

Execute only after R12 is complete and the program state is `release_candidate_verified`.

## Mission

Perform the final evidence-based acceptance review, remove stale or misleading scaffolding, reconcile all documentation/state, and produce the operational handoff for a clean AURA release candidate or authorized release.

Do not add new features in this prompt. Failed gates cause rollback, disablement, or return to the owning track.

## Required context

Read:

- `current-state.json` and all release gates;
- capability matrix;
- risk, decision, evidence, and program ledgers;
- RC evidence package;
- accepted ADRs 034–047;
- master plan final checklist;
- README, AGENTS, active specs, operations/support/install/uninstall/privacy/security docs;
- release artifact metadata and hashes;
- legacy current-state/session-starter/prompt references that may be stale.

## A. Full capability acceptance

For every capability marked user-reachable:

- production adapter exists;
- capability manifest and schema exist;
- runtime health is truthful;
- permission/dependency/model/account requirements are visible;
- policy and confirmation are enforced;
- execution and verification are distinct;
- failure/cancel/restart behavior is defined;
- required evidence class exists;
- UI and localization exist;
- privacy and retention behavior is documented;
- release scope includes it.

Downgrade or disable any capability that cannot meet its declared status.

## B. End-to-end clean acceptance

From a clean supported Mac/profile verify the final supported scope:

1. install and Gatekeeper launch;
2. onboarding and permissions;
3. Push to Talk/text conversation in Turkish and English;
4. local model/degraded behavior;
5. registered app/file/URL capability;
6. bound confirmed mutation and verification;
7. browser/mail/calendar read workflow;
8. VS Code/test/coding-agent workflow;
9. approved computer-use task if in release scope;
10. memory inspection/correction/deletion;
11. accessibility/keyboard/VoiceOver path;
12. offline/no-model/no-account/dependency missing states;
13. sleep/wake/restart/task recovery;
14. update and rollback;
15. emergency stop;
16. support bundle privacy;
17. uninstall/factory reset.

Use the exact release candidate artifact, not a developer build.

## C. Security and privacy final review

Confirm:

- no critical unaccepted risk;
- no secret in source/config/log/event/prompt/crash/support artifact;
- all network paths are enforced;
- OAuth scopes are least privilege and revocable;
- privileged helpers and IPC are verified;
- external content has no authority;
- secure fields and unapproved screen capture remain blocked;
- update/plugin/model/package trust roots are valid;
- incident and kill-switch procedures are executable.

## D. Documentation and repository cleanup

- reconcile README product claims with actual release scope;
- update installation, onboarding, permissions, privacy, models, integrations, recovery, update, uninstall, and support docs;
- remove or archive obsolete starter/status prose;
- redirect legacy prompt sequence to the new operational state where appropriate without rewriting historical ledgers;
- remove dead production wiring, unused placeholders, stale flags, and misleading “complete” comments;
- retain tests/fakes but mark them test-only;
- update ADR and decision indexes;
- ensure no TODO/FIXME represents required release behavior;
- ensure examples contain no secrets or unsafe defaults.

## E. State closure

Update:

- capability matrix to final statuses;
- release gates with evidence IDs;
- risk register with closed/accepted/open post-release risks;
- evidence index and RC/release artifact references;
- program ledger with final acceptance verdict;
- current state to `release_candidate_verified` or `released` only with explicit authority;
- anti-amnesia handoff to operations/maintenance rather than implementation.

Do not mark `released` merely because the artifact is release-ready. Public release requires explicit authorization and evidence of the release action.

## F. Operational handoff

Produce a compact maintainer runbook covering:

- supported versions/hardware/OS;
- architecture/process topology;
- critical dependencies/models/integrations;
- build/sign/notarize/update commands;
- health diagnostics;
- incident containment;
- grant/token revocation;
- safe mode/recovery;
- database/config/memory migration;
- known limitations and excluded capabilities;
- release/rollback authority;
- next maintenance review dates.

## Final completion gate

The Runtime Completion Program is complete only when:

- every mandatory gate is passed or explicitly scoped out/accepted by authorized ownership;
- clean end-to-end acceptance passes;
- capability claims match evidence;
- no false-success or unauthorized-action blocker remains;
- security/privacy/accessibility/release sign-offs exist;
- documentation and state are consistent;
- the artifact is installable, updateable, recoverable, and uninstallable;
- the operational handoff is complete.

If any mandatory gate fails, return the program to the owning track and update the handoff. Do not use partial success language to claim AURA is fully operational.

End with `15_SESSION_CLOSEOUT.prompt.md` and a final concise release-candidate or release report.
