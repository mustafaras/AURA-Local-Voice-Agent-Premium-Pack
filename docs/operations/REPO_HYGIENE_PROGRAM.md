# AURA Repository Hygiene Program

**Status:** Planned; control plane prepared, execution not started
**Owner:** Repository maintainer
**Baseline:** `main` / `e1004795e56df8c171422261eace96543649cf51`
**Scope:** Source, tests, build artifacts, Git object database, tooling, CI, secrets, dependencies, documentation, ledgers, and agent context

This is the canonical human-readable plan for the repository-hygiene pass. It is intentionally separate from the product second-pass chain in `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`. The two programs may share evidence, but a repository-hygiene task must not silently close a product, release, beta, permission, or live-hardware gate.

## Executive verdict

The repository is source-buildable and its local Python/runtime and governance checks are green, but it is not hygiene-ready for release work. The highest-risk finding is a damaged Git object database: `git fsck --full --strict --no-reflogs` reported 199 bad SHA-1 file entries and 8,901 dangling objects. The active documentation also contains toolchain and test-count drift, build/test scripts contain hard-coded Command Line Tools paths, the CI does not exercise several important gates, and the ledgers/context are large enough to create avoidable amnesia and synchronization risk.

No cleanup, deletion, garbage collection, re-pack, dependency installation, secret rotation, commit, push, merge, release, or deployment was performed while preparing this program.

## Evidence snapshot

| Area | Observed evidence | Interpretation | Confidence |
|---|---|---|---|
| Git integrity | `git fsck --full --strict --no-reflogs` exits non-zero; 199 `bad sha1 file` entries and 8,901 dangling objects; `HEAD` remains readable | P0 recovery gate before any object cleanup | High |
| Source build | Fresh temporary `swift build --build-path <temp>` passed | Code is buildable under the selected CLT toolchain; linker path warnings remain | High |
| Python runtime | `PYTHONPATH=Runtime/chatterbox python3 -m unittest discover -s Runtime/chatterbox/tests` passed 4/4 | Runtime tests are locally healthy but absent from CI | High |
| Governance | Runtime validator, second-pass validator, and 26 script tests passed | Existing control plane is healthy for its recorded scope | High |
| Worktree | Dirty by design with prior product/state/release/second-pass changes and untracked program files | Prompts must preserve ownership and classify before mutation | High |
| Tooling | `swift-format`, `swiftlint`, `shellcheck`, `yamllint`, `actionlint`, `gitleaks`, `trufflehog`, and `pre-commit` are unavailable; full Xcode is unavailable | Tool availability is a gate, not permission to install silently | High |
| Drift | README says 19 test bundles while `scripts/aura-test.sh` enumerates 21; active docs mix macOS 26/27 and Swift 6/6.4 | Canonical active baseline must be selected and historical records preserved | High |
| Generated files | `.build` about 1.7G; Chatterbox `.venv` about 1.2G; caches and `.DS_Store` files are ignored and untracked | Quarantine/classification is needed before cleanup | High |
| Source risk | Production `try!`, `as!`, `@unchecked Sendable`, detached tasks, and gated `print()` sites exist | Requires bounded audit, not blind replacement | Medium/High |
| Secrets | Narrow tracked scan found no real credential; one intentional token-shaped test fixture is present | Add scanner policy and fixture sentinel before claiming secret hygiene | Medium |

The snapshot is a starting fact set. Every prompt must refresh facts that can drift and must record the command, exit status, environment, and artifact path in `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`.

## Gap register and ordered prompts

The chain is strictly linear. A prompt is cognitively complete only when its symptom, mechanism, root cause, resolution, falsification test, residual risk, and next-step safety are written down and independently checked. A green command without that reasoning is not completion.

### HYGIENE-00 — Baseline freeze and ownership inventory

Capture branch/HEAD/remote, worktree status, ignored/untracked inventory, tool versions, authority, current ledgers, and a tamper-evident evidence snapshot. Do not edit product code or delete anything.

**Prompt:** `H-000_BASELINE_FREEZE_AND_EVIDENCE_CAPTURE.prompt.md`
**Depends on:** none
**Exit:** baseline evidence and ownership classification exist; otherwise remain blocked.

### HYGIENE-01 — Git object database recovery

Investigate bad object entries and dangling-object state. Establish a verified external backup or clean clone before any repair. Garbage collection, prune, repack, object deletion, reset, and clean are forbidden until explicit recovery authority and a rollback path exist.

**Prompt:** `H-001_GIT_OBJECT_DATABASE_RECOVERY.prompt.md`
**Depends on:** HYGIENE-00
**Exit:** recovery evidence proves a healthy authoritative repository and preserves dirty work; otherwise remain blocked.

### HYGIENE-02 — Dirty worktree and artifact quarantine

Separate user-owned work from generated artifacts and build caches. Quarantine or archive only with a recoverable mapping. Do not use `git clean -fdx` or broad deletion.

**Prompt:** `H-002_DIRTY_WORKTREE_AND_ARTIFACT_QUARANTINE.prompt.md`
**Depends on:** HYGIENE-01
**Exit:** every dirty/untracked path has an owner, disposition, and recovery reference.

### HYGIENE-03 — Ignore rules and generated-file hygiene

Make ignore rules explicit and minimal, verify that generated artifacts are not tracked, and add regression checks for caches, local environments, IDE state, and OS metadata. Preserve intentional fixtures and manifests.

**Prompt:** `H-003_IGNORE_RULES_AND_GENERATED_FILE_HYGIENE.prompt.md`
**Depends on:** HYGIENE-02
**Exit:** ignore coverage is proven by a clean fixture/inventory test and no accidental tracking is introduced.

### HYGIENE-04 — Canonical toolchain and documentation drift

Choose one active baseline consistent with `AGENTS.md`, `README.md`, `TOOLCHAIN.md`, and `Package.swift`; update active prose and scripts; preserve historical ledger facts as historical. Remove or parameterize hard-coded developer-directory paths.

**Prompt:** `H-004_CANONICAL_TOOLCHAIN_AND_DOCUMENTATION_DRIFT.prompt.md`
**Depends on:** HYGIENE-03
**Exit:** active documentation, scripts, CI, and package metadata agree and the limitation matrix is explicit.

### HYGIENE-05 — Swift formatting, lint, and strict-concurrency gate

Define pinned formatter/linter configuration and a reproducible command. Validate strict concurrency and warnings policy. Installation requires separate authority; unavailable tools remain a recorded blocker.

**Prompt:** `H-005_SWIFT_FORMAT_LINT_AND_STRICT_CONCURRENCY.prompt.md`
**Depends on:** HYGIENE-04
**Exit:** configuration and tool versions are reproducible, or a blocked capability has an owner and safe next action.

### HYGIENE-06 — Unsafe constructs and debug-output audit

Review production `try!`, `as!`, `@unchecked Sendable`, detached tasks, and `print()` diagnostics. Fix only evidence-backed defects; otherwise document an ADR or bounded exception with tests.

**Prompt:** `H-006_UNSAFE_CONSTRUCTS_AND_DEBUG_OUTPUT.prompt.md`
**Depends on:** HYGIENE-05
**Exit:** every finding is fixed, justified, or explicitly deferred with a falsification test and owner.

### HYGIENE-07 — Test matrix, CI, and coverage hygiene

Align the 21 Swift bundles, 4 Python runtime tests, governance validators, coverage threshold, diff checks, and CI artifact retention. Distinguish local results from observed CI results. Pin action revisions according to repository policy.

**Prompt:** `H-007_TEST_MATRIX_CI_AND_COVERAGE_HYGIENE.prompt.md`
**Depends on:** HYGIENE-06
**Exit:** a reproducible matrix proves what is run, where, and what remains unavailable.

### HYGIENE-08 — Secret, dependency, and supply-chain hygiene

Establish secret scanning with a safe fixture policy, review dependency provenance and lockfiles, and add actionable CI checks. Never put secret values in prompts, logs, fixtures, or ledgers.

**Prompt:** `H-008_SECRET_DEPENDENCY_AND_SUPPLY_CHAIN_HYGIENE.prompt.md`
**Depends on:** HYGIENE-07
**Exit:** scanners, dependency checks, and false-positive handling are reproducible without exposing credentials.

### HYGIENE-09 — Ledger, context, and architecture hygiene

Keep append-only history while reducing duplication through authored successor/pointer documents. Define Tier-0/Tier-1 context loading, summarize large ledgers, and audit architecture boundaries using evidence rather than prose volume.

**Prompt:** `H-009_LEDGER_CONTEXT_AND_ARCHITECTURE_HYGIENE.prompt.md`
**Depends on:** HYGIENE-08
**Exit:** a new session can recover truth from a bounded read order and every projection cross-checks its source.

### HYGIENE-10 — Final hygiene gate and closeout

Run all available validators, tests, scans, diff checks, inventory checks, and context synchronization checks. Record open risks and the next safe action. This prompt cannot authorize product release or Git delivery.

**Prompt:** `H-010_FINAL_REPO_HYGIENE_GATE_AND_CLOSEOUT.prompt.md`
**Depends on:** HYGIENE-09
**Exit:** all acceptance criteria pass or are explicitly blocked with evidence; state remains synchronized.

## Hard boundaries

- Never run `git clean`, `git reset`, `git prune`, `git gc`, `git repack`, delete `.git/objects`, or rewrite history without a verified backup, an explicit recovery decision, and a recoverable rollback plan.
- Never overwrite or “tidy” dirty user-owned files merely because they are inconvenient.
- Never install formatters, linters, scanners, dependencies, models, or Xcode components without explicit authority.
- Never treat a local build, simulated boundary, or static YAML parse as live, release, beta, signing, notarization, or deployment evidence.
- Never rewrite append-only ledgers. Create a successor note and pointer when a document must be superseded.
- Never advance to the next prompt if the current cognitive completion gate, evidence record, validator, or session closeout is missing.

## Definition of done

The hygiene program is complete only if the final gate proves: repository object integrity or a formally documented recovery blocker; clean ownership/disposition of dirty and generated files; canonical toolchain/documentation; reproducible formatting/lint/security/dependency checks or explicit blockers; safe production-code audit decisions; aligned test/CI/coverage matrix; bounded context and ledger loading; synchronized state/manifest/gap/ledger projections; and a new-session handoff with exact evidence. Product and release gates remain governed by the existing second-pass program.

## Control-plane links

- [Read-first context](../../AURA_RUNTIME_COMPLETION/context/REPO_HYGIENE_READ_FIRST.md)
- [Control contract](../../AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_CONTROL_CONTRACT.md)
- [Prompt contract](../../AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_PROMPT_CONTRACT.md)
- [Prompt manifest](../../AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_PROMPT_MANIFEST.json)
- [Machine state](../../AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json)
- [Focused ledger](../../AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md)
- Validator: `python3 scripts/validate_repo_hygiene_program.py`
