# ADR-008 — Typed Shell / Process Runner Architecture

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-07-26 |
| **Author** | GitHub Copilot |
| **Supersedes** | — |

## Context

Phase 7 of the AURA implementation roadmap requires a typed shell / process execution layer. The subsystem must satisfy the normative requirements in `docs/subsystems/14_TERMINAL_AND_SHELL.md`: typed commands with executable and argument arrays, no `shell=true` by default, bounded output, timeouts, cancellation, output redaction, filesystem-change evidence, and interactive PTY support. Shell execution is a `.mutation`-tier `Capability.shellExec` already present in `AuraCore`, so the new layer must integrate cleanly with the existing policy engine.

## Decision

1. **New target `AuraShell`.** Add a dedicated SwiftPM library target `AuraShell` and matching test target `AuraShellTests`. It depends only on `AuraCore`.

2. **Core shell model lives in `AuraCore`.** Reusable value types that cross subsystem boundaries are kept in `AuraCore`:
   - `ShellConfiguration` in `AuraConfiguration.swift`.
   - `Command` value type with executable, arguments, working directory, environment allowlist, timeout, expected exit codes, and risk tier.
   - `RedactionRule` / `OutputRedactor` primitives for secret and path redaction.
   - `ShellEventPayloads.swift` for `CommandStartedEvent`, `CommandCompletedEvent`, `CommandOutputEvent`, and `CommandCancelledEvent`.
   - `AuraError.shellError(String)` domain.

3. **`ProcessRunner` actor.** `AuraShell/ProcessRunner.swift` wraps `Foundation.Process`. It is responsible for:
   - Starting a typed `Command`.
   - Streaming stdout/stderr with byte and line bounds (`maxOutputBytes`, `maxOutputLines`).
   - Enforcing a timeout via `withTimeout` / `withThrowingTaskGroup`.
   - Supporting cooperative cancellation via `Task.isCancelled` and process termination.
   - Returning a typed `ShellResult` containing exit code, redacted stdout/stderr, duration, and filesystem evidence.
   - Never invoking a shell interpreter by default; `Command` always carries an executable path and `[String]` arguments.

4. **Filesystem-change evidence.** `AuraShell/FilesystemEvidence.swift` captures recursive directory tree hashes before and after execution for directories declared in the command. It produces deterministic, comparable digests without retaining file contents.

5. **PTY abstraction.** `AuraShell/PTYSession.swift` exposes an interactive pseudo-terminal interface. The implementation uses POSIX `openpty`/`forkpty` only when explicitly requested via `Command.ptyRequested`; the default typed runner does not allocate a PTY. The interface is protocol-based so tests can inject a deterministic PTY double.

6. **Policy adapter.** `AuraShell/ShellPolicyAdapter.swift` translates a `Command` into a `PolicyEvaluationRequest` for `Capability.shellExec`, using the existing `ResourcePattern.command(regex:)`, `.argument(allowed:)`, and `.environment(keys:)` patterns.

7. **Public coordinator.** `AuraShell/AuraShell.swift` is the actor clients consume. It validates commands, optionally evaluates policy via an injected policy port, delegates execution to `ProcessRunner`, emits typed shell events, and returns `ShellResult`. It does not execute commands directly.

8. **Testing strategy.** Tests use deterministic fixtures and protocol-based doubles. Real-process tests only invoke `/bin/echo`, `/bin/date`, `/bin/sleep`, and `/bin/false` so they are safe and predictable on macOS. Cancellation, timeout, output bounds, exit-code mismatch, and redaction paths are exercised with mocks and spies. No test depends on live Accessibility or network access.

## Security and privacy impact

- Redaction is applied to process output **before** events are emitted or logged; `AuraLogger` only receives `.public` data.
- Environment variables are filtered against an explicit allowlist.
- Commands are typed values, not raw strings, preventing shell interpolation and hidden privilege escalation.
- Filesystem evidence hashes directories the command has declared in advance; it does not scan the entire filesystem.
- The PTY path is gated behind an explicit flag and is intended only for interactive sessions that the user initiates.

## Operational impact

- Adds one new library and one new test target, increasing build time modestly.
- Shell execution now has bounded output and timeouts, preventing runaway processes from exhausting memory.
- Event payloads let downstream observers monitor command lifecycle without receiving secrets.

## Migration

No breaking migration. The `AURA` executable target will gain a dependency on `AuraShell` once tool adapters begin routing shell intents. This ADR records the target dependency as a future safe action.

## Validation evidence

- Unit tests for `Command` validation, `OutputRedactor`, `ProcessRunner` timeout/cancellation/bounds, and `FilesystemEvidence` hashing.
- Contract tests for `ShellPolicyAdapter` mapping to `Capability.shellExec`.
- Integration smoke test that `/bin/echo` returns the expected redacted output.
- Full build and test suite pass via `./scripts/aura-test.sh`.

## Consequences

- **Positive:** AURA now has a typed, bounded, policy-aligned shell execution layer with evidence capture and privacy-preserving logging.
- **Negative:** PTY support relies on POSIX APIs that require careful resource cleanup; future hardening around signal handling and terminal size may be needed.
- **Risk:** Misconfiguration of environment allowlists or redaction regexes could leak secrets; these are controlled by `ShellConfiguration` and validated at startup.

## Related

- `prompts/implementation/07_07_TYPED_SHELL.prompt.md`
- `docs/subsystems/14_TERMINAL_AND_SHELL.md`
- `docs/security/29_SECRET_HANDLING.md`
- `Sources/AuraCore/PolicyTypes.swift`
- `Sources/AuraCore/AuraConfiguration.swift`
- `Sources/AuraCore/ActorID.swift`
- `Sources/AuraShell/AuraShell.swift`
- `Tests/AuraShellTests/AuraShellTests.swift`
