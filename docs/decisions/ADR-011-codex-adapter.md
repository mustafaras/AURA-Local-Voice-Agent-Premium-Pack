# ADR-011 — Codex CLI Adapter Architecture

- Status: Accepted
- Date: 2026-07-25
- Owners: GitHub Copilot
- Supersedes: —
- Superseded by: —

## Context

Phase 10 of the AURA implementation roadmap requires integrating the OpenAI Codex CLI as a durable, policy-gated tool adapter: explicit sandbox and approval mapping, structured events, budgets, cancellation, and integration tests, using only verified current interfaces. `Sources/AuraAgent/` was a placeholder before this phase; no Codex/Claude/Copilot code existed.

Two facts discovered during implementation materially shaped the design and are recorded here because they contradict what the phase's own planning assumed at the outset:

1. **`codex exec` (the non-interactive subcommand) has no `-a`/`--ask-for-approval` flag.** That flag exists only on the top-level interactive `codex` command (verified via `codex exec --help` on the installed `codex-cli 0.142.0`). There is therefore no config-driven, per-run "ask for approval" toggle to set for non-interactive execution at all — approval must happen entirely upfront, before spawning, through AURA's own policy engine.
2. **The JSONL event schema was only partially documented publicly.** Top-level event types (`thread.started`, `turn.started`, `turn.completed`, `turn.failed`, `item.started`, `item.completed`, `error`) are confirmed by official docs (developers.openai.com/codex, redirects to learn.chatgpt.com/docs/non-interactive-mode). Nested item and `usage` field names were not. With explicit user authorization, one real `codex exec --json` smoke test was run (a trivial read-only "ping" prompt, first against the OpenAI/ChatGPT backend — which returned a real usage-limit error, itself a useful sample — then successfully against a local Ollama-backed `--oss` provider to get a complete run). The captured, real JSONL output is checked in at `Tests/AuraAgentTests/Fixtures/codex_smoke_success.jsonl` and `codex_smoke_quota_error.jsonl` and is the basis for `CodexEventNormalizer`'s decode logic.

## Decision

1. **Extend `AuraShell`/`ProcessRunner` with a streaming execution path, not a Codex-local process spawner.** `AuraShell`'s own doc comment declares it "the only shell target type imported by higher-level modules," and `ProcessRunner` already owns all safety-relevant state (`Command.validate` allowlisting, timeout-deadline loop, `activeProcesses`/`cancellationRequested` for cancellation). The existing `run()` buffers all output via `readDataToEndOfFile()` only after the process exits — unusable for reacting to JSONL events live. A new `runStreaming(_:executionID:) -> AsyncThrowingStream<ProcessStreamEvent, Error>` was added inside `ProcessRunner.swift` (same file, so it can see `private` state), using a `FileHandle.readabilityHandler` + per-stream `LineAccumulator` actor idiom modeled on `PTYSession.drainOutput`. `run()` itself is untouched. `AuraShell.executeStreaming(...)` wraps it with the same before/after `FilesystemEvidence` capture as `execute()`. This is additive only and is directly reusable by the Claude/Copilot adapters `ActorID` already anticipates (`.agentClaude`, `.agentCopilot`, `.agentOllama` cases already existed).

2. **`Command.standardInputText`.** `Command.validate()` rejects any argument containing `;`, `|`, or `&&`. Codex prompts are free natural-language text that routinely contains those characters. Rather than loosen validation, `Command` gained a `standardInputText: String?` field; the prompt is piped to the process's stdin and the pipe is closed for EOF, never passed as a positional CLI argument.

3. **Approval is always upfront, never mid-run.** Since `codex exec` has no approval flag at all (see Context), `CodexArguments.make` never emits one — sandboxing is controlled solely via `-s/--sandbox`. Authorization happens once, before a process is ever spawned, through `PolicyEngine.evaluate(_:)`: `.allow` proceeds with exactly the sandbox tier that was evaluated; `.deny` yields `.approvalDecision(allowed: false, …)` and never spawns a process; `.confirm` yields `.approvalRequested(…)`, awaits a `CodexApprovalPresenting.present(challenge:)` response, round-trips it through `PolicyEngine.submitConfirmation(_:)` (echoing `challenge.expectedHash` — the engine's existing tamper-evident nonce/hash mechanism), and only proceeds on the resulting `.allow`. This required zero changes to `TaskState`/`AuraTaskEngine` — the whole confirm cycle is synchronous inside `CodexAdapter.perform(...)`, and `CodexTaskRunner.execute` is already long-running async.

4. **Two Codex-specific capabilities, not the generic `Capability.agentRun`.** `Capability.agentCodexReadOnly` (`.reversible`) and `Capability.agentCodexRun` (`.destructive`) were added to `PolicyTypes.swift`, following the existing per-domain pattern (`vscodeOpen`, `taskEnqueue`, …) so grants/denies can target Codex specifically. `-s danger-full-access` is a real, verified `codex exec` flag, but `CodexSandboxTier` has no case for it and no capability maps to it — unreachable by construction, not merely avoided by convention.

5. **`CodexAdapter` is a single actor that owns the whole per-run flow.** `run(request:actor:sessionID:correlationID:causationID:)` returns one `AsyncThrowingStream<CodexNormalizedEvent, Error>` covering the entire lifecycle — policy gate, approval, spawn, JSONL consumption, budget checks, completion — built by spawning one `Task` inside the `AsyncThrowingStream`'s continuation closure. (An earlier draft evaluated policy *before* constructing the stream, which meant `.approvalRequested`/`.approvalDecision` were only ever emitted to the audit event bus, never to the caller-visible stream — a real bug, caught by `codexAdapterConfirmPathRoundTripsThroughPolicyEngine` in `CodexTaskRunnerTests.swift` and fixed by moving all work inside the continuation.) Every event is also mirrored onto an injectable `AuraEventBus` (default `.shared`, matching `AuraTaskEngine`'s convention) as a typed `Codex*Event` audit record.

6. **`CodexEventNormalizer` is built in two explicitly-labeled tiers.** Tier A decodes only the verified top-level `type` discriminator. Tier B (informed by the smoke test) adds real field extraction for the nested `item.type` discriminator, confirmed for `error` (`{id, type, message}`) and `reasoning`/`agent_message` (`{id, type, text}`) items, plus `turn.failed`'s nested `error.message` (not a flat field, contrary to the top-level `error` event's flat `message`) and `turn.completed`'s `usage` object (extracted leniently as `[String: Int]`, since key names, though observed as `input_tokens`/`cached_input_tokens`/`output_tokens`/`reasoning_output_tokens`, are not documented as a closed set). Item types named in Codex's documentation but not observed (`command_execution`, `file_change`, `plan_update`, `mcp_tool_call`, `web_search`) are carried opaquely via `.unclassifiedItem(rawItemType:sequence:rawLine:)` rather than given fabricated structured fields.

7. **Process-level failure is surfaced even when Codex never gets to write a JSONL error line.** If the process is killed by `ProcessRunner`'s timeout/cancellation or exits with an unexpected code, `codex exec` may never emit its own `turn.failed`/`error` line. `CodexAdapter.perform` inspects every `.completed(ProcessResult)` from the shell layer and yields a synthesized `.turnFailed(message:)` whenever `wasCancelled`, `wasTimedOut`, or the exit code was unexpected — so a killed process can never be mistaken for a quiet success by a caller that only pattern-matches on `.turnCompleted`/`.turnFailed`.

8. **Budgets: time and file-writes are real; tokens/cost are honestly advisory-only in v1.** Time is enforced for free by `ProcessRunner`'s existing deadline loop (`CodexRunRequest.timeoutSeconds`, capped by `CodexConfiguration.maxTimeoutSeconds`). File writes are enforced live: `CodexAdapter` counts `.unclassifiedItem(rawItemType: "file_change", …)` occurrences and, past `CodexConfiguration.maxFileWritesPerRun`, cancels the process and yields `.budgetExceeded`. Token/cost budgets are captured and reported (`CodexTurnCompletedEvent.observedTokenUsage`) but not enforced — `usage` only arrives at `turn.completed`, the end of the single, non-looping `codex exec` invocation this phase implements, so there is nothing left to cancel by the time it is known. `CodexConfiguration.maxTokensPerRun`/`maxEstimatedCostUSD`/`costPerTokenUSD` default to `nil` (no-op) pending a future multi-turn runner where a genuine pre-turn check becomes possible.

9. **Cancellation uses the same `withTaskCancellationHandler` idiom already proven in `AuraTaskEngine.run`.** Both `CodexAdapter.run`'s returned stream (`continuation.onTermination`) and `ProcessRunner.runStreaming`'s own stream propagate cancellation down to a real `process.terminate()`, not just a cooperative flag.

10. **`CodexTaskRunner: TaskRunner` requires zero `AuraTasks` changes.** There is no type-based runner registry in `AuraTaskEngine` — the runner instance is passed explicitly at `enqueue(request:runner:)`. `CodexTaskRunner` reads working directory and sandbox tier from `TaskRequest.context`'s existing free-form `[String: String]` dictionary (`codex.workingDirectory`, `codex.sandbox` keys).

11. **`codex exec resume` (session persistence across turns) is explicitly out of scope** for this phase — `CodexRunRequest` has no `resumeSessionID` field, avoiding a half-wired parameter. Noted as a named follow-up.

## Alternatives considered

- **Pass `--dangerously-bypass-approvals-and-sandbox`.** Rejected outright — AGENTS.md forbids dangerous bypass flags, and the whole point of this phase is policy-gated execution.
- **Poll for an interactive approval prompt mid-run.** Rejected once it was confirmed `codex exec` has no such flag or mechanism; there is no channel to answer a prompt that cannot be issued.
- **Deliver the prompt as a positional CLI argument.** Rejected — `Command.validate()` correctly rejects arguments containing shell metacharacters, and prompts routinely contain them; stdin delivery was added instead.
- **Build a Codex-local `Process` spawner inside `AuraAgent`, bypassing `AuraShell`.** Rejected — would duplicate `ProcessRunner`'s validation/cancellation/timeout logic or silently skip it, a real safety regression, and `AuraShell` is documented as the sole sanctioned execution boundary.
- **Fabricate structured fields for undocumented item types (file_change, plan_update, command_execution).** Rejected per AGENTS.md's "never fabricate" rule; carried opaquely instead, pending real observation.
- **Widen `ShellConfiguration`'s default `allowedExecutablePaths` to include `/opt/homebrew/bin`.** Rejected — would loosen the shared, general-purpose shell configuration for unrelated code paths. `CodexConfiguration.derivedShellConfiguration()` builds a narrowly-scoped `ShellConfiguration` instead, allowlisting only the configured Codex binary.

## Security and privacy impact

- The Codex prompt is delivered via stdin and deliberately excluded from the `PolicyEvaluationRequest` target/audit summary (`CodexPolicyAdapter`) — policy logs record where a run may touch, not the free-text content of what the user asked.
- `-a never`'s non-existence for `exec` is not a gap: the sandbox tier (`read-only`/`workspace-write`) is the sole gate, chosen by policy evaluation, not by the adapter.
- `danger-full-access` is unreachable — no `CodexSandboxTier` case, no capability maps to it.
- `--add-dir` targets and the working directory are validated against `CodexConfiguration.allowedWorkingDirectories` before being placed in argv; `CodexArguments.make` throws rather than silently narrowing or widening what was requested.
- No raw audio, screenshots, or secrets are part of any Codex event payload; `observedTokenUsage` and item text are the only free-form content carried, and item text is only ever the model's own visible reasoning/answer, not user secrets.

## Operational impact

- `AuraAgent` gains `AuraShell`, `AuraPolicy`, and `AuraTasks` as dependencies (previously only `AuraCore`, `AuraAudio`).
- `AuraShell`/`ProcessRunner` gain purely additive streaming API surface; existing `AuraShellTests` (16 tests) pass unmodified, confirming zero regression on `run()`.
- Neither `CodexAdapter` nor `CodexTaskRunner` are wired into the `AURA` app composition root in this phase — matches existing precedent (VS Code/Tasks adapters aren't wired in yet either).

## Migration

No breaking migration. `AuraConfiguration` gained a `codex: CodexConfiguration` field with full defaults; existing serialized configuration without a `codex` key decodes unchanged (`decodeIfPresent` + defaults, matching every other subsystem configuration in `AuraConfiguration.swift`).

## Validation evidence

- `swift build --build-path /tmp/aurabuild-codex --target AuraShell` / `AuraAgent` / `AuraShellTests` / `AuraAgentTests` — all exit 0, zero warnings.
- `./scripts/aura-test.sh /tmp/aurabuild-codex AuraShellTests` — 20/20 tests pass (16 pre-existing + 4 new streaming tests), run 3× consecutively with no flakiness observed.
- `./scripts/aura-test.sh /tmp/aurabuild-codex AuraAgentTests` — 46/46 tests pass, run 3× consecutively with no flakiness observed.
- Authorized real invocations: `codex exec --json -s read-only -c approval_policy=never --skip-git-repo-check "Reply with exactly one word: ping"` against the ChatGPT-authenticated backend returned a real usage-limit error (`turn.failed`) — captured as `Tests/AuraAgentTests/Fixtures/codex_smoke_quota_error.jsonl`; the same invocation with `--oss --local-provider ollama -m minimax-m3:cloud` completed successfully — captured as `Tests/AuraAgentTests/Fixtures/codex_smoke_success.jsonl`. Both are exercised by `CodexEventNormalizerTests`' fixture-based tests.

## Consequences

- **Positive:** AURA has a real, policy-gated Codex adapter with live JSONL streaming, upfront approval mapping through the existing confirm/response mechanism, and reusable streaming plumbing for future Claude/Copilot/Ollama adapters.
- **Negative:** Item-level classification only covers `error`/`reasoning`/`agent_message`; `file_change`, `plan_update`, `command_execution`, `mcp_tool_call`, and `web_search` remain opaque pending real observation (would require an authorized run that actually exercises file/command tools, out of scope for this phase's minimal smoke test).
- **Risk:** Token/cost budgets are advisory-only; a single expensive turn cannot currently be pre-empted mid-flight on cost grounds. `codex exec resume` is unimplemented, so multi-turn conversations are not yet supported.

## Related

- `prompts/implementation/10_10_CODEX_ADAPTER.prompt.md`
- `docs/subsystems/17_CODEX_CONTROLLER.md`
- `docs/subsystems/15_AGENT_ORCHESTRATOR.md`
- `Sources/AuraShell/ProcessRunner.swift`
- `Sources/AuraShell/AuraShell.swift`
- `Sources/AuraCore/CodexEventPayloads.swift`
- `Sources/AuraAgent/CodexAdapter.swift`
- `Sources/AuraAgent/CodexEventNormalizer.swift`
- `Sources/AuraAgent/CodexTaskRunner.swift`
- `Tests/AuraAgentTests/Fixtures/codex_smoke_success.jsonl`
- `Tests/AuraAgentTests/Fixtures/codex_smoke_quota_error.jsonl`
