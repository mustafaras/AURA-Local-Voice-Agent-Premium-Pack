# ADR-010 — Durable Task Engine Architecture

- Status: Accepted
- Date: 2026-08-03
- Owners: GitHub Copilot
- Supersedes: —
- Superseded by: —

## Context

Phase 9 of the AURA implementation roadmap requires a durable task engine that can outlive process crashes and restarts. The engine must support enqueueing, prioritization, bounded concurrency, cancellation, pause/resume, progress and checkpoint reporting, retry with backoff, and crash recovery. Use cases include "Ask Codex to run tests" and "Push it" from the acceptance scenarios, both of which create long-running, interruptible work that must leave an auditable trace in the ledger.

The engine sits behind the policy engine: models and agents propose tasks, the policy engine authorizes them, and the engine executes and records outcomes. All task lifecycle changes must be observable through typed events so that the orchestrator and UI can render status without polling raw state.

## Decision

1. **New target `AuraTasks`.** Add a dedicated SwiftPM library target `AuraTasks` and matching test target `AuraTasksTests`. It depends on `AuraCore` and `AuraStore`.

2. **Public value types in `AuraCore`.** Task-related cross-boundary types live in `AuraCore` so that callers (orchestrator, policy engine, UI) do not need to depend on `AuraTasks`:
   - `TaskState`, `TaskPriority`, `TaskStatus`, `TaskRequest`, `TaskConfiguration` in `AuraCore/TaskTypes.swift`.
   - `TaskEnqueuedEvent`, `TaskStateChangedEvent`, `TaskProgressEvent`, `TaskPausedEvent`, `TaskResumedEvent`, `TaskCancelledEvent`, `TaskCompletedEvent` in `AuraCore/TaskEventPayloads.swift`.

3. **Actor `AuraTaskEngine`.** The engine is a single actor that owns all mutable state:
   - `tasksByID: [UUID: AuraTask]` for O(1) lookups.
   - `TaskQueue` priority queue ordered by `TaskPriority` raw value descending, then FIFO.
   - `activeRunners: [UUID: Task<Void, Never>]` to bound concurrency and allow cancellation.
   - `TaskStoreBackend` for SQLite-backed persistence of task snapshots and checkpoints.

4. **Internal aggregate `AuraTask`.** `AuraTask` is a lock-protected class (NSLock, `@unchecked Sendable`) holding mutable state: state, attempt count, progress, latest checkpoint, error message. It exposes immutable `TaskStatus` snapshots.

5. **Runner protocol `TaskRunner`.** Execution is pluggable. A runner produces a `TaskPlan` and then executes the task through `TaskExecutionContext`. The context lets the runner report progress, save checkpoints, and check cooperative cancellation. Runners are declared `Sendable` and run outside the engine actor so they may perform blocking or long-running work.

6. **Persistence model.** `TaskSnapshot` and `TaskCheckpoint` are `Codable` and stored via `AuraStore` key-value and dedicated checkpoint records. On `recoverState()` the engine loads all snapshots, rebuilds the queue, and re-pumps so that pending and paused tasks resume where they left off. Running snapshots from the previous process are treated as pending for retry.

7. **Concurrency and cancellation.**
   - `maxConcurrentTasks` limits how many tasks run simultaneously.
   - `queueCapacity` limits how many tasks the engine will track overall (`tasksByID.count < queueCapacity`).
   - Each dequeued task runs in a `Task` stored in `activeRunners`; cancelling the task propagates `CancellationError` through the runner.
   - `finish(task:state:error:)` is idempotent and refuses to overwrite a user-requested `.cancelled` or `.paused` state, preventing runner completion from racing past an explicit cancel or pause request.

8. **Retry and expiry.** `maxRetries` controls retry attempts. After each AuraError or generic failure the engine increments the attempt counter and re-enqueues if retries remain; otherwise it finishes failed. `deadline` and `inactivityTimeoutSeconds` are stored but enforcement is left to future phases that add a watchdog timer.

9. **Policy capabilities.** Four task capabilities are added to `AuraCore/PolicyTypes.swift`:
   - `Capability.taskEnqueue`
   - `Capability.taskCancel`
   - `Capability.taskResume`
   - `Capability.taskDelete`

10. **Configuration.** `TaskConfiguration` is part of `AuraConfiguration` with sensible defaults: `defaultMaxRetries=3`, `defaultInactivityTimeoutSeconds=300`, `checkpointRetentionDays=30`, `maxConcurrentTasks=3`, `queueCapacity=100`.

11. **Testing strategy.** Tests use deterministic doubles: a `BlockingRunner` with a `Gate` for start/cancel/pause synchronization, a `CountingRunner` for checkpoint tests, and a `FailingRunner` for retry exhaustion. A `Capture` actor collects events from the bus to assert lifecycle ordering without relying on wall-clock sleeps.

## Alternatives considered

- **Run tasks directly on the engine actor.** Rejected because long-running or blocking runner work would block queue management and event emission.
- **Use Swift Structured Concurrency task groups for the pool.** Rejected because the engine must keep per-task cancellation handles and persist task state independently; a dictionary of named tasks is simpler and recoverable.
- **Store tasks only in memory and rely on external orchestrator replay.** Rejected because crash recovery is an explicit acceptance scenario.
- **Expose `AuraTask` publicly.** Rejected; callers interact with immutable `TaskStatus` and `TaskRequest`, keeping the aggregate free to evolve.

## Security and privacy impact

- Task payloads (`objective`, `context`) may contain user intent; they are persisted locally in SQLite and never sent to remote services by the engine.
- Checkpoints may include tool-specific state; the engine treats them as opaque `Codable` dictionaries and stores them with the same local-only guarantee as the rest of `AuraStore`.
- All mutating operations (`enqueue`, `cancel`, `pause`, `resume`, `delete`) will eventually require policy authorization; this phase adds the engine primitives and capabilities.
- No secrets, ambient audio, screenshots, or personal memory are exposed in task payloads or events.

## Operational impact

- Adds one new library and one new test target.
- Increases `AuraStore` schema version implicitly through new table usage by `TaskStoreBackend`.
- Provides the foundation for tool adapters (Codex, Claude, Git) to submit durable work.

## Migration

No breaking migration. Existing targets do not depend on `AuraTasks`. The `AURA` executable target will gain a dependency once tool adapters begin enqueueing tasks.

## Validation evidence

- `swift build --build-path /tmp/aurabuild --target AuraTasks` passes.
- `swift build --build-path /tmp/aurabuild --target AuraTasksTests` passes.
- `./scripts/aura-test.sh /tmp/aurabuild AuraTasksTests` passes: 10/10 tests.
- Full suite `./scripts/aura-test.sh /tmp/aurabuild-final` passes with 0 failed bundles across AuraCoreTests, AuraStoreTests, AuraAudioTests, AuraSTTTests, AuraAgentTests, AuraAutomationTests, AuraShellTests, AuraVSCodeTests, AuraTasksTests, and AURAIntegrationTests.

## Consequences

- **Positive:** AURA now has a typed, evented, recoverable task engine that satisfies the crash-restart acceptance scenario and provides the lifecycle hooks tool adapters need.
- **Negative:** The engine currently relies on cooperative cancellation inside runners; a runner that ignores `context.checkCancellation()` or `Task.checkCancellation()` cannot be forcibly interrupted without also cancelling the host process.
- **Risk:** Future phases must add a real watchdog for `deadline` and `inactivityTimeoutSeconds`; the values are stored and surfaced but not actively enforced yet.

## Related

- `prompts/implementation/09_09_TASK_ENGINE.prompt.md`
- `docs/subsystems/15_AGENT_ORCHESTRATOR.md`
- `Sources/AuraCore/TaskTypes.swift`
- `Sources/AuraCore/TaskEventPayloads.swift`
- `Sources/AuraTasks/AuraTaskEngine.swift`
- `Sources/AuraTasks/AuraTask.swift`
