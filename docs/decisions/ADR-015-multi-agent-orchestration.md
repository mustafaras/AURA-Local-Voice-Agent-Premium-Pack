# ADR-015 — Multi-Agent Orchestration

- Status: Accepted
- Date: 2026-07-26
- Owners: Claude Sonnet 5 (Claude Code)
- Supersedes: —
- Superseded by: —

## Context

Phase 14 of the AURA implementation roadmap requires worktree isolation and Planner → Implementer → Reviewer workflows with bounded iterations, conflict recording, and evidence-based adjudication, per `prompts/implementation/14_14_MULTI_AGENT.prompt.md` and the normative specs `docs/subsystems/15_AGENT_ORCHESTRATOR.md` / `docs/subsystems/16_MULTI_AGENT_PROTOCOL.md`. Phases 10–13 already built four independent, policy-gated backend adapters (`CodexAdapter`, `ClaudeAdapter`, `CopilotAdapter`, `OllamaAdapter`) and a durable task engine (`AuraTaskEngine`/`TaskRunner`), but nothing yet composed multiple agents over isolated git state, and no orchestration-level conflict/escalation logic existed.

Two architectural facts, discovered while designing this phase, materially shaped the result:

1. **`TaskExecutionContext`'s initializer is `internal` to `AuraTasks`.** A cross-module orchestrator (living in `AuraAgent`) cannot construct one itself, so driving role agents through `AuraTaskEngine.enqueue(request:runner:)` would only ever expose truncated progress strings and a generic completed/failed/cancelled outcome — never the actual plan text, diff, or review verdict a Planner→Implementer→Reviewer workflow needs to pass between roles.
2. **`CodexNormalizedEvent`/`ClaudeNormalizedEvent`/`CopilotNormalizedEvent` are structurally near-identical** (`runStarted`, `approvalRequested`/`approvalDecision`, a text-content case, `turnCompleted`/`turnFailed`, a generic error case, `budgetExceeded`, unclassified/unrecognized passthrough), a direct consequence of ADR-011/012/013 building all three CLI adapters on the same `AdapterProcessExecuting`/streaming-JSONL pattern. This made a thin, mechanical reduction to a common shape realistic without inventing anything.

## Decision

1. **The orchestrator drives backend adapters directly, not through `AuraTaskEngine`/`TaskRunner`.** A new protocol, `OrchestratedAgentRunning` (`Sources/AuraAgent/OrchestratedAgent.swift`), reduces any backend's normalized events to a small, backend-agnostic `OrchestrationAgentEvent` enum (`.text`, `.approvalDenied`, `.turnCompleted`, `.turnFailed`, `.budgetExceeded`). `CodexOrchestratedAgent`/`ClaudeOrchestratedAgent`/`CopilotOrchestratedAgent` (`OrchestratedAgentAdapters.swift`) are thin wrappers over the already-verified real adapters — every event case they consume is a real, previously-confirmed shape (see ADR-011/012/013); nothing new is fabricated. Policy evaluation, upfront approval, and budget enforcement all still happen exactly where they already did, inside each wrapped adapter — the orchestrator never bypasses that gate.
   - **Ollama is deliberately not wrapped.** Its adapter drives a structured local HTTP API (`OllamaStructuredRequest`), not a free-text CLI turn; forcing it into this text-turn shape now would be a premature, likely-wrong abstraction. Named follow-up.
   - One real bug caught during implementation: `CodexNormalizedEvent.itemError` (a *nested, non-fatal* per-item warning — e.g. a model-metadata-fallback notice — distinct from `turnFailed`/`codexError`) was initially mapped to `.turnFailed`, which would have made `codex_smoke_success.jsonl`'s real successful run register as a failure. `CodexTaskRunner` itself already treats `.itemError` as ignorable (`default: break`); `CodexOrchestratedAgent` was fixed to match, caught by `codexOrchestratedAgentMapsRealSuccessFixtureToTextAndCompletion`.

2. **`WorktreeManager` (`Sources/AuraAgent/WorktreeManager.swift`) is a new actor**, policy-gated the same way the CLI adapters gate themselves: it calls `PolicyEngine.evaluate` itself before ever touching `git` (two new capabilities, `Capability.agentWorktreeCreate`/`agentWorktreeRemove`, both `.mutation`), since `AuraShell.execute`'s own doc comment already documents that it "constructs but does not enforce" a policy decision. `git` is spawned through a dedicated `AuraShell` scoped to only the configured `git` binary, mirroring `CodexConfiguration.derivedShellConfiguration()`.
   - One mutable task gets exactly one worktree, at `<repositoryRoot>/.aura-worktrees/<taskID>`, on a dedicated branch `aura/orchestration-<taskID>` — satisfying the master prompt's "allow one mutable task per worktree" concurrency rule structurally (an in-memory `reservedPaths`/`activeWorktrees` guard rejects a second `prepareWorktree` for the same task ID before ever invoking `git`).
   - `removeWorktree` defaults to `force: false` — `git worktree remove` on a dirty tree fails loudly rather than silently discarding uncommitted work; callers must explicitly pass `force: true`.
   - **The orchestrator never auto-removes a worktree**, on any outcome (approved, escalated, or failed). Verified real: `docs/subsystems/16`'s reviewer/adjudication rules produce a decision about the *change*, not authorization to mutate the base branch — merging is a separate, out-of-scope, independently policy-gated follow-up action. A `.failed` outcome that occurs *after* worktree creation embeds the worktree path/branch in its reason string (a real gap caught during test design: without this, a failed implementer run would leave an orphaned worktree with no way for a caller to find it).
   - **`WorktreeConfiguration.allowedWorkingDirectories` defaults to wildcard patterns (`["$HOME/*", "$TMPDIR/*"]`), unlike `CodexConfiguration`'s literal `["$HOME", "$TMPDIR"]`.** Discovered while writing real `git`-backed tests: `Command.validate`'s own allowlist check (`pathMatches`) is exact-match unless a pattern ends in `*` — a *different*, blunter check than `WorkingDirectoryAllowlist.requireAllowed`'s prefix matching used by `CodexArguments`/`ClaudeArguments`. Codex/Claude/Copilot sidestep this by only ever being pointed at a literal configured directory in their own tests; a worktree manager cannot, since its entire purpose is nested subdirectories (`<repositoryRoot>/.aura-worktrees/<taskID>`). Widening only `WorktreeConfiguration`'s own default (not the shared `ShellConfiguration`/`CodexConfiguration`/etc. defaults) keeps this change scoped to the one type that genuinely needs it.

3. **`MultiAgentOrchestrator` (`Sources/AuraAgent/MultiAgentOrchestrator.swift`) is a new actor implementing two of the Multi-Agent Collaboration Protocol's four named patterns:**
   - **Planner → Implementer → Reviewer**, with a bounded review/correct loop (`Configuration.maxReviewIterations`, default 3). Each iteration: the reviewer is shown the *actual `git diff`* against the base ref (captured by `WorktreeManager.diff`, read-only, unauthenticated — analogous to `FilesystemEvidence` snapshotting elsewhere, not policy-gated since it mutates nothing) and, when a `validationCommand` is supplied, real validation-command output — never the implementer's own self-reported summary, directly satisfying the spec's "reviewer must not rely solely on implementer's summary."
   - **Specialist swarm** — separable tasks run concurrently (`withTaskGroup`) each in its own isolated worktree via `WorktreeManager`, with no cross-task adjudication (worktree isolation is what makes the pattern safe by the spec's own definition: "use only when tasks are separable and worktrees prevent conflicts").
   - **"Parallel proposals → adjudicator" and "Implementer → independent reviewer → corrector" are explicit, named follow-ups, not silently half-implemented.** `OrchestrationPattern` (in `Sources/AuraCore/OrchestrationTypes.swift`) has exactly two cases, matching what is actually implemented.

4. **Evidence-based adjudication is a boolean AND, not an either/or.** `evidenceApproved = reviewerApproved && (validation?.passed ?? true)` — the reviewer's own verdict is parsed by `ReviewVerdictParser` from a fixed, orchestrator-defined terminal marker (`VERDICT: APPROVE` / `VERDICT: REQUEST_CHANGES: <reason>`, required to be the response's last line; anything else, including the marker followed by more prose, is `.unparseable` and treated as a disagreement, never a silent approval). When a validation command is supplied and it fails, that overrides a bare `VERDICT: APPROVE` — verified directly by `orchestratorValidationFailureOverridesReviewerApproval`, which runs the reviewer fake returning `APPROVE` against a *real* `/usr/bin/false` validation command and asserts the run still escalates. This is the concrete meaning of "no raw model output may become an executable action" for this phase: the reviewer's verdict alone can never authorize treating the run as done.

5. **Disagreements are recorded, not silently dropped.** Every non-approved review iteration appends an `OrchestrationConflict` (iteration number, parsed verdict, validation pass/fail) to the run's `conflicts` array and emits a typed `OrchestrationConflictRecordedEvent` on `AuraEventBus` — the same audit-trail mechanism every other subsystem in this codebase uses for decisions (`PolicyDecisionEvent`, `CodexApprovalDecisionEvent`, etc.), not a new logging channel. Exhausting `maxReviewIterations` emits `OrchestrationEscalatedEvent` and returns `.escalated(worktreePath:branch:iterations:conflicts:)` rather than ever forcing an approval.

6. **Recursive/uncontrolled agent spawning is prevented two ways: structurally and by budget.** Structurally, `MultiAgentOrchestrator` only ever constructs/calls `OrchestratedAgentRunning` role agents — there is no code path by which a run could spawn another `MultiAgentOrchestrator`. Additionally, `Configuration.maxTotalAgentInvocations` (default 20) is checked before every single role-agent invocation (planner, implementer, reviewer, and each corrector pass) across a run; hitting the ceiling emits `OrchestrationBudgetExceededEvent` and returns `.budgetExceeded(reason:)` immediately, without spawning the next agent. `Configuration.maxSpecialistTasks` (default 8) separately bounds a swarm call's fan-out before any worktree is touched.

7. **`AuraError.orchestrationError` and `ActorID.orchestrator` are new, minimal additions**, following the exact per-subsystem pattern already established by `codexError`/`claudeError`/`copilotError`/`ollamaError` and `agentCodex`/`agentClaude`/`agentCopilot`/`agentOllama` — this phase is a peer subsystem, not a special case.

## Alternatives considered

- **Drive role agents through `AuraTaskEngine`/`TaskRunner`.** Rejected: `TaskExecutionContext`'s `internal init` means only `AuraTasks` itself can construct one, and the engine's `TaskCompletedEvent.summary` carries only a generic "Task \(state): \(objective)" string, not the plan text/diff/verdict a multi-role workflow must pass between stages. Extending `AuraTasks`'s public surface just for this would have meant a cross-cutting change to durable-task infrastructure for a need `AuraAgent` can satisfy on its own by driving the adapters directly (which is what the adapters' own `run(...)` streams are already designed for).
- **Trust the reviewer's verdict alone.** Rejected per the spec's own "reviewer must not rely solely on implementer's summary" rule and this project's "no raw model output may become an executable action" constraint — a validation command, when supplied, is real, independent evidence that can override a bare approval.
- **Auto-merge an approved worktree's branch back into the base ref.** Rejected as out of scope — merging mutates the base branch (a `.mutation`/`.destructive`-tier action in its own right) and deserves its own explicit policy gate and human/caller decision, not an implicit side effect of adjudication passing.
- **Wrap `OllamaAdapter` into `OrchestratedAgentRunning` now for completeness.** Rejected — its structured-request/response shape is different enough from a free-text CLI turn that a rushed adapter would likely misrepresent its actual capabilities (e.g. no natural multi-turn "make these changes" objective the way Codex/Claude/Copilot support). Named follow-up.
- **Implement all four named collaboration patterns this phase.** Rejected — "parallel proposals → adjudicator" needs a genuine N-proposal adjudication algorithm not yet designed, and "implementer → independent reviewer → corrector" is materially the same bounded loop as Planner→Implementer→Reviewer minus the planning step; forcing both in now risked a rushed, redundant abstraction. Named follow-ups, tracked via `OrchestrationPattern` deliberately having only two cases.

## Security and privacy impact

- Worktree creation/removal are both real filesystem mutations gated through `PolicyEngine.evaluate` before `git` is ever invoked — a denial is enforced in-process (verified by `worktreeManagerDenyPathNeverTouchesGit`: no directory is created on disk).
- The validation command (when supplied) is gated through `Capability.shellExec` the same way any other shell execution in this codebase must be, per `AuraShell.execute`'s documented "constructs but does not enforce" gap.
- No raw prompt/objective text, diff content, or validation output is included in any *audit* event payload (`WorktreeCreatedEvent`, `OrchestrationRunStartedEvent`, etc. carry only paths, branch names, iteration counts, and pattern/outcome enums) — matching the existing convention (e.g. `CodexPolicyAdapter` deliberately excludes the raw prompt from policy audit summaries).
- The reviewer's verdict can never, by itself, authorize a destructive action; only a caller-supplied, separately-policy-gated validation command and the reviewer's parsed text combine to produce an `.approved` outcome, and even then the outcome only names a worktree/branch — it does not merge, push, or delete anything.

## Operational impact

- `Sources/AuraCore/` gains `OrchestrationTypes.swift` (pure data types: `WorktreeHandle`, `OrchestrationPattern`, `ReviewVerdict`, `ValidationOutcome`, `OrchestrationConflict`, `OrchestrationOutcome`, `SpecialistTask`/`SpecialistResult`) and `OrchestrationEventPayloads.swift` (audit event payloads), plus additive fields on `ActorID`, `AuraError`, `Capability`, and a new `WorktreeConfiguration` threaded into `AuraConfiguration` following the exact pattern of `CodexConfiguration`/`ClaudeConfiguration`/etc.
- `Sources/AuraAgent/` gains `WorktreeManager.swift`, `OrchestratedAgent.swift`, `OrchestratedAgentAdapters.swift`, `ReviewVerdictParser.swift`, `MultiAgentOrchestrator.swift` — no changes to any existing `AuraAgent` file's public API.
- Neither `WorktreeManager` nor `MultiAgentOrchestrator` is wired into the `AURA` app composition root in this phase — matches existing precedent (none of the Codex/Claude/Copilot/Ollama adapters are wired in yet either, per `ledger/CURRENT_STATE.md`).
- `AuraTasks`/`AuraTaskEngine`/`TaskRunner` are entirely untouched by this phase.

## Migration

No breaking migration. `AuraConfiguration` gained a `worktree: WorktreeConfiguration` field with full defaults; existing serialized configuration without a `worktree` key decodes unchanged (`decodeIfPresent` + defaults, matching every other subsystem configuration in `AuraConfiguration.swift`).

## Validation evidence

- `swift build --build-path /tmp/aurabuild-final14` (full project) — exit 0, zero non-linker warnings.
- `./scripts/aura-test.sh /tmp/aurabuild-final14` (full default 8-bundle sweep) — 261/261 tests pass across `AURAIntegrationTests`, `AuraAgentTests`, `AuraAudioTests`, `AuraAutomationTests`, `AuraCoreTests`, `AuraSTTTests`, `AuraShellTests`, `AuraStoreTests`.
- `./scripts/aura-test.sh /tmp/aurabuild-final14 AuraPolicyTests` — 17/17 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-final14 AuraTasksTests` — 10/10 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-final14 AuraVSCodeTests` — 13/13 pass.
- Combined total across all 11 bundles: **301 tests, 0 failures** (270 pre-existing + 31 new: 7 `WorktreeManagerTests`, 9 `ReviewVerdictParserTests`, 5 `OrchestratedAgentAdaptersTests`, 10 `MultiAgentOrchestratorTests`).
- `AuraAgentTests` (202 tests, including all 31 new) re-run 3× consecutively — no flakiness observed, including the concurrency-sensitive specialist-swarm and real-`git` worktree tests.
- **Real, authorized `git` invocations** (`/usr/bin/git`, version 2.54.0 Apple Git-157) against scratch repositories under `$HOME/.aura-worktree-tests/`/`$HOME/.aura-orchestrator-tests/` (removed after each test run): `git init`, `git worktree add -b <branch> <path> <baseRef>` (verified real filesystem isolation — a write inside one worktree is absent from the main repo and from a sibling worktree), `git worktree remove` (clean succeeds without `--force`; dirty fails without `--force` and succeeds with it), `git diff <baseRef>` (reflects real uncommitted changes). A hands-on scratch-repo exploration (outside the automated suite, in `/private/tmp/.../scratchpad/worktree-test/`) additionally confirmed: re-adding a worktree at an already-used path fails with a real `git` error (defense-in-depth beyond the in-memory `reservedPaths` guard), and branches survive worktree removal (not auto-deleted).
- **Real `/usr/bin/false` invocation** via a real `AuraShell` in `orchestratorValidationFailureOverridesReviewerApproval`, proving evidence-based adjudication overrides a bare model "APPROVE" with a genuinely failing validation command, not a mocked result.
- Secret-pattern grep (`sk-`, `AKIA`, `gh[pousr]_`, PEM private-key headers, JWT shape) across every new/modified Phase 14 file — no matches.

## Consequences

- **Positive:** AURA has a real, policy-gated multi-agent orchestrator with genuine `git`-backed worktree isolation, a bounded review/correct loop whose adjudication cannot be satisfied by model self-report alone, typed audit events for every disagreement/escalation, and a concurrent specialist-swarm pattern — all reusing the already-verified Codex/Claude/Copilot adapters without touching their internals.
- **Negative:** Ollama cannot yet participate as an orchestration role agent (structural mismatch, not an oversight). Two of the four named collaboration patterns ("parallel proposals → adjudicator", "implementer → independent reviewer → corrector") are unimplemented. There is no automatic integration (merge) path from an approved worktree back to the base branch — by design, but it means this phase alone does not close the loop from "approved" to "shipped."
- **Risk:** `ReviewVerdictParser`'s convention depends on the reviewer agent actually honoring the orchestrator's own prompt instruction to end with a bare `VERDICT:` line; a model that ignores this produces `.unparseable`, which is treated conservatively (as a disagreement) rather than blocking the run outright, but a persistently non-compliant reviewer backend would exhaust review iterations on format alone rather than substance. `WorktreeConfiguration`'s wildcard-pattern default is a deliberate, scoped divergence from the Codex/Claude/Copilot/Ollama configurations' literal-only default; future subsystems reusing `allowedWorkingDirectories` patterns should not assume all such fields behave identically.

## Related

- `prompts/implementation/14_14_MULTI_AGENT.prompt.md`
- `docs/subsystems/15_AGENT_ORCHESTRATOR.md`
- `docs/subsystems/16_MULTI_AGENT_PROTOCOL.md`
- `docs/decisions/ADR-011-codex-adapter.md`, `ADR-012-claude-adapter.md`, `ADR-013-copilot-adapter.md`, `ADR-014-ollama-adapter.md`
- `Sources/AuraAgent/WorktreeManager.swift`
- `Sources/AuraAgent/OrchestratedAgent.swift`
- `Sources/AuraAgent/OrchestratedAgentAdapters.swift`
- `Sources/AuraAgent/ReviewVerdictParser.swift`
- `Sources/AuraAgent/MultiAgentOrchestrator.swift`
- `Sources/AuraCore/OrchestrationTypes.swift`
- `Sources/AuraCore/OrchestrationEventPayloads.swift`
- `Tests/AuraAgentTests/WorktreeManagerTests.swift`
- `Tests/AuraAgentTests/OrchestratedAgentAdaptersTests.swift`
- `Tests/AuraAgentTests/ReviewVerdictParserTests.swift`
- `Tests/AuraAgentTests/MultiAgentOrchestratorTests.swift`
