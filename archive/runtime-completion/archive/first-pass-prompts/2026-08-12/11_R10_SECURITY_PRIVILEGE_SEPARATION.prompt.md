# R10 — Security and Privilege Separation Prompt

Execute after R4, R5, and R6 expose their real control, network, OAuth, and agent boundaries.

## Mission

Reduce AURA’s compromise blast radius before external beta. Separate privileged local-control operations from model/network/UI processes, enforce network and secret boundaries, authenticate local IPC, and apply adversarial defenses to every externally influenced production path.

## Required context

Read:

- threat model and security ADRs;
- policy, grants, confirmation, prompt-injection, network allowlist, Keychain/secret code;
- plugin host and entitlements;
- app/main/helper composition;
- screen/computer-use executor;
- shell and coding-agent process boundaries;
- browser/mail/calendar OAuth/network clients;
- updater/release requirements;
- adversarial tests and incident-response docs;
- ADR-044 proposal.

## A. Process and privilege topology

Move toward least-privilege authenticated helpers:

- UI app: UI, consent, presentation; no arbitrary execution.
- Runtime service: dialogue/planning/state; no direct generated input or unrestricted shell.
- Audio service/helper where justified: audio/STT/TTS with no broad filesystem/network authority.
- Automation helper: Accessibility, Apple Events, ScreenCaptureKit, generated input; no model reasoning.
- Agent helper: typed shell and coding CLIs with scoped directories/network/budgets.
- Plugin host: existing isolated plugin execution.

Use XPC or a comparably authenticated local IPC mechanism supported by the platform. Every request must be typed, versioned, capability-scoped, hash-bound, freshness/replay protected, and policy-authorized.

## B. Entitlements and sandboxing

For each process define:

- required entitlements;
- forbidden entitlements;
- network access;
- filesystem scope;
- Accessibility/screen/automation scope;
- Keychain access group;
- IPC clients;
- code-signing requirement;
- failure/degraded behavior.

Do not claim OS-enforced confinement when only application policy exists.

## C. Network enforcement

Make network policy mandatory for every network client:

- centralized client factory;
- allowed scheme/domain/port/path where applicable;
- loopback/Ollama policy;
- DNS/IP and redirect revalidation;
- TLS validation;
- proxy behavior;
- download size/type/hash bounds;
- per-capability/account/provider grants;
- privacy-safe audit;
- no direct unregistered `URLSession` path.

Include subprocess/CLI network assumptions in the agent-helper policy.

## D. Secrets and OAuth

- store tokens/keys only in Keychain or approved secret references;
- use incremental least-privilege OAuth scopes;
- support revocation and expiry;
- prevent tokens in args/env/logs/events/crashes/prompts/support bundles;
- isolate provider accounts;
- bind callbacks/state/PKCE as required by current provider standards;
- threat-model refresh tokens, local redirect handlers, and malicious callback attempts.

## E. Content provenance and injection defense

Apply to production browser, mail, calendar, file, OCR, terminal, plugin, and agent outputs:

- untrusted provenance labels;
- instruction/content separation;
- no authority carryover;
- schema validation;
- capability allowlist;
- sensitive-data redaction;
- policy re-evaluation at action time;
- indirect prompt-injection test corpus.

## F. Plugins and supply chain

- verify manifests, payload hashes, signatures, vendor roots, revocation, quarantine, update, and rollback;
- do not claim public marketplace readiness without real vendor PKI/catalog evidence;
- pin dependencies/toolchains/models and produce SBOM/checksums;
- validate packaged helper source and nested signatures;
- reject unverified runtime-loaded code.

## G. Security operations

Update:

- threat model;
- incident response;
- security review schedule;
- vulnerability reporting;
- log/evidence preservation;
- safe containment and grant revocation;
- independent review findings tracker.

## Tests

Required:

- unauthorized IPC client/request;
- replay/nonce/version/schema tampering;
- helper capability escalation;
- path/domain/redirect/DNS bypass;
- secret leakage across logs/events/env/args/crash/support bundle;
- OAuth CSRF/state/PKCE/scope/revocation;
- screen/mail/web/document/terminal indirect injection;
- model tool spoofing;
- policy/confirmation bypass;
- secure-field/generated-input protection;
- emergency stop across process boundaries;
- plugin/package/signature tampering;
- compromised-helper assumptions and containment;
- dependency/model hash mismatch;
- denied network/offline degraded behavior.

## Independent review

Before completion, obtain or schedule an independent architecture/security review of:

- process topology;
- IPC authentication;
- policy/confirmation;
- OAuth/Keychain;
- network enforcement;
- computer use;
- updater trust;
- plugin trust.

Critical findings block completion unless explicitly accepted by the authorized release owner with scope/expiry.

## Completion gate

R10 is complete only when privileged powers are separated or an explicitly reviewed equivalent boundary exists, all production network paths are enforced, secrets/OAuth are hardened, external content is non-authoritative, adversarial tests pass, supply-chain evidence exists, and no critical unaccepted security risk remains for external beta.

Accept ADR-044, update risk/evidence/capability/state/ledger/handoff, unblock R11 with R9, and run closeout.
