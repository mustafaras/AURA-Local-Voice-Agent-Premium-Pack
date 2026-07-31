# R11 — Release Engineering and Continuous Operations Prompt

Execute only after R9 and R10 are complete.

## Mission

Produce a reproducible, installable, Developer-ID-signed, hardened, notarized, updateable, recoverable AURA build that works on a clean supported Mac without developer tools. Implement continuous-operation essentials: launch at login, signed updates, rollback, safe mode, diagnostics, migration, recovery, and uninstall.

No public release is authorized by this prompt. Signing, notarization, distribution, update publication, and installation require explicit session authority.

## Required context

Read:

- accepted ADRs 045/046 or their proposals;
- `Package.swift`, build/test/sign scripts, app/helper plists and entitlements;
- CI configuration;
- all process/helper topology from R10;
- update/recovery/operations docs;
- database/config/memory migrations;
- permission onboarding;
- capability and release gates;
- current official Apple documentation for Developer ID, Hardened Runtime, notarization, stapling, Gatekeeper, ServiceManagement, login items, and packaging;
- selected updater framework/mechanism official documentation.

## A. Stable build and archive pipeline

Create a reproducible archive pipeline that:

- pins Xcode/Swift/SDK/tool versions;
- builds all Swift, helper, extension, Python/runtime, and resource components;
- embeds exact approved model/helper manifests without secret material;
- signs every nested executable in correct order;
- applies process-specific entitlements;
- preserves Hardened Runtime;
- emits symbols and version/build metadata;
- verifies bundle structure, plists, entitlements, designated requirements, and signatures;
- produces DMG/PKG or approved distribution artifact;
- generates checksums/SBOM/release manifest.

Prefer a maintained Xcode/archive workflow or rigorously tested equivalent. Development/ad-hoc signing remains separate.

## B. Developer ID and notarization

With explicit authority and credentials:

- use Developer ID identities;
- secure timestamp;
- submit via current official Notary API/`notarytool` path;
- retain and inspect logs;
- staple ticket;
- validate with `codesign`, `spctl`, and clean-machine Gatekeeper;
- verify nested helpers/extensions and TCC identity behavior.

Never store signing credentials in the repository, prompts, logs, or CI artifacts.

## C. Launch at login and lifecycle

Implement user-controlled launch at login through the supported ServiceManagement mechanism. Provide:

- enable/disable UI;
- visible status and repair path;
- no hidden re-enable;
- sleep/wake, login/logout, crash, and update behavior;
- bounded restart policy;
- privacy mode preserved;
- microphone/wake behavior consistent with user settings.

## D. Signed update and rollback

Implement an auditable update mechanism with:

- signed manifest and package;
- version/channel compatibility;
- package hash verification;
- secure transport;
- atomic install;
- downgrade/replay prevention;
- helper/schema/model compatibility checks;
- staged rollout/kill switch;
- rollback on failure;
- migration preflight and backup;
- user-visible release notes and consent where required.

Do not create custom cryptography when a mature audited mechanism satisfies the architecture.

## E. Recovery and diagnostics

Implement:

- safe-mode launch;
- reset grants;
- reset model/cache;
- reset eligible memory/configuration;
- rebuild projections/database integrity check;
- support bundle with strict redaction and user review;
- update rollback;
- factory reset preserving required audit/security records;
- full uninstall of app, helpers, login items, caches, optional models, and user data according to explicit choice.

## F. Upgrade and migration

Test:

- supported prior version to current;
- interrupted update;
- failed migration;
- database/config/memory/plugin model migration;
- permission persistence and invalidation;
- helper protocol compatibility;
- rollback after migration;
- low disk and corrupted artifact.

## G. CI and artifact evidence

CI must produce linked evidence for:

- builds/tests/coverage/adversarial checks;
- bundle/signature verification;
- SBOM/checksums;
- update manifest validation;
- packaging;
- notarization dry run or actual authorized run;
- artifact retention and provenance.

A workflow file without a run is not evidence.

## Clean-machine acceptance matrix

Validate at minimum:

- clean user profile;
- no developer tools;
- permissions not granted;
- permissions granted then revoked;
- offline first launch;
- no local model/CLI;
- update from previous build;
- rollback;
- low disk;
- app/helper crash;
- uninstall and reinstall;
- launch at login enable/disable;
- Gatekeeper/quarantine behavior.

## Completion gate

R11 is complete only when an authorized release-candidate artifact is reproducibly built, nested-signed, notarized, stapled, Gatekeeper-accepted on a clean supported Mac, launch at login works, signed update/rollback/recovery/uninstall pass, migrations are safe, support bundles are private, and CI/artifact evidence is retained.

Accept ADRs 045/046, update gates/evidence/risk/capability/state/ledger/handoff, mark R12 ready, and run closeout.
