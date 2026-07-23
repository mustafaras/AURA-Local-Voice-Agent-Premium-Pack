# Master Product and Engineering Specification


> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


## Functional requirements

### Voice
- Continuous local audio capture while enabled.
- Configurable wake phrase.
- Voice activity detection with adaptive noise calibration.
- Optional speaker verification.
- Streaming bilingual Turkish/English transcription.
- Semantic end-of-turn detection.
- Barge-in and interruption.
- Local speech synthesis with voice selection and rate control.
- Audible and visual privacy state indicators.

### Desktop control
- Launch, activate, hide, and quit applications.
- Open files, folders, URLs, and workspaces.
- Read active application and window metadata.
- Use Accessibility APIs for structured interface control.
- Use ScreenCaptureKit only for approved content.
- Generate keyboard and pointer events only through a policy-controlled executor.
- Prefer application-specific adapters.

### Coding-agent orchestration
- Start, resume, stop, and inspect Codex, Claude Code, Copilot, and local-agent tasks.
- Use isolated Git worktrees for parallel write-capable tasks.
- Capture structured events, diffs, test results, costs, and permissions.
- Support author/reviewer and planner/implementer workflows.
- Prevent agents from recursively spawning uncontrolled agents.
- Require explicit authorization for push, release, deployment, secret access, and destructive commands.

### Memory
- Working, session, project, user-preference, and procedural memory.
- Evidence, confidence, provenance, retention, and sensitivity metadata.
- Append-only task and decision ledger.
- Deterministic context reconstruction.
- Contradiction detection and supersession rather than silent overwrite.
- User-visible memory inspection and deletion.

## Quality attributes

### Safety
Deny by default; least privilege; explicit scope; time-bounded grants; transactional execution; rollback where possible.

### Reliability
Idempotent commands, durable queues, restart recovery, state machines, bounded retries, circuit breakers, and health checks.

### Privacy
Local-first processing, no ambient audio persistence by default, selective capture, redaction, encrypted storage, and clear retention controls.

### Performance
Separate real-time audio paths from heavy reasoning and computer vision. Avoid loading multiple large local models concurrently on a 16 GB system.

### Maintainability
Protocol-driven subsystems, strict interfaces, dependency injection, generated schemas, feature flags, and architectural decision records.

## Required deliverables

- Signed SwiftUI menu-bar application.
- Local background service with launch-at-login support.
- Audio, policy, memory, task, and automation services.
- Application adapters for Finder, VS Code, Terminal, browser, Codex, Claude Code, and Ollama.
- Test harnesses with synthetic audio and deterministic UI fixtures.
- Installation, permissions, recovery, and uninstallation guides.
