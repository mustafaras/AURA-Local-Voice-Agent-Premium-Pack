# ADR-034 — Accessibility and CLI Privilege Separation Behind Least-Privilege Helpers

- **Status:** In Progress
- **Date:** 2026-07-30
- **Owners:** GitHub Copilot
- **Supersedes:** —
- **Superseded by:** —

## Context

AURA's main `AURA` executable currently performs Accessibility API calls (`ApplicationServices`) and typed shell/PTY execution (`Foundation.Process`) in-process. Because these capabilities require the containing process to be unsandboxed, the main app cannot enable App Sandbox or OS-enforced network confinement. `AuraPluginHost` already proves the repository can build, sign, and verify a separate App Sandbox helper with network denied; that pattern has not yet been applied to automation or shell execution.

The project release gates list "Main-process Accessibility/CLI privilege separation behind least-privilege helpers for OS-enforced network confinement" as a prerequisite before any release claim. Closing this gate is a material architecture change that requires an explicit decision.

## Decision

1. **Migrate Accessibility and shell execution behind separate least-privilege helpers.** Introduce two new sandboxed executable targets, modeled on `AuraPluginHost`, plus an IPC layer in `AuraCore`:
   - `AuraAutomationHelper` — runs Accessibility (`AXUIElement*`, `AXIsProcessTrustedWithOptions`) and `NSWorkspace` application lifecycle calls on behalf of the main app.
   - `AuraShellHelper` — runs `Foundation.Process`, streaming pipes, and interactive PTY sessions on behalf of the main app.
   - `AuraHelperKit` / shared IPC types in `AuraCore` — typed request/response envelopes, protocol versioning, sandbox attestation, bounded I/O, and helper lifecycle management.

2. **Main app becomes sandbox-ready.** Once the migration is complete, the main `AURA` executable will no longer link `ApplicationServices` directly and will not spawn child processes. It will request automation and shell operations through the helpers. `Resources/AURA.entitlements` may then add `com.apple.security.app-sandbox` without breaking Accessibility/CLI functionality. Until the migration is complete, the main app remains intentionally non-sandboxed.

3. **Each helper is App Sandbox enabled with network denied.** Each helper's entitlements follow `AuraPluginHost.entitlements`:
   - `com.apple.security.app-sandbox` = true.
   - `com.apple.security.network.client` = false.
   - `com.apple.security.network.server` = false.
   - No microphone, camera, or user-selected file entitlements unless a later ADR justifies them.
   - Helper self-attests via `SecTaskCreateFromSelf` + `SecTaskCopyValueForEntitlement` and fails closed if the sandbox is missing.

4. **Typed IPC over stdin/stdout with bounded payloads.** Each helper reads a single JSON request envelope from stdin (bounded, e.g. ≤1 MiB) and writes a single JSON response envelope to stdout. The main app launches and manages helper `Process` instances; requests are serialized and responses are deserialized using shared `AuraCore` types. The protocol is versioned and request nonces are echoed in responses to prevent cross-request confusion.

5. **Policy decisions stay in the main app.** The helpers execute only requests the main app has already authorized through `PolicyEngine`. The helper validates the request shape, target allowlists, and execution bounds, but it does not re-run policy. This preserves the existing "policy engine authorizes, adapters execute" contract.

6. **Helper executables are pinned and hash-verified at launch.** The main app obtains each helper path from configuration. Before launch it verifies the helper bundle signature/designated requirement and, where practical, a pinned SHA-256 of the helper executable. `scripts/verify-signature.sh` is extended to assert helper sandbox entitlements and to assert the main app lacks Accessibility/shell entitlements once migration completes.

7. **Fallback behavior during migration.** The in-process `AuraAutomation` and `AuraShell` implementations remain operational until the helper path is configured and verified. A feature flag or build setting controls whether helper-based execution is enabled; the default remains in-process until this ADR's acceptance gate passes. This avoids breaking existing tests and UI behavior during the transition.

8. **Test strategy.** Existing `AuraAutomationTests` and `AuraShellTests` continue to run against in-process doubles/spies. New tests exercise the helper IPC layer and helper-spy boundaries without requiring live Accessibility permission. The helper executables gain their own minimal unit tests (e.g. `--attest-only` and malformed-request rejection). The full repository coverage ratchet (≥70%) must continue to pass.

## Alternatives considered

- **Single helper for both AX and CLI.** Rejected because the two capabilities have different privilege profiles and failure modes. Combining them would force a broader sandbox and complicate least-privilege reasoning.
- **XPC instead of stdin/stdout JSON.** Rejected for the v1 boundary because `Foundation.Process` + `Pipe` is simpler, easier to sandbox, and matches the proven `AuraPluginHost` pattern. XPC may be reconsidered in a future ADR if IPC latency or lifecycle becomes a bottleneck.
- **Leave everything in-process and rely on policy allowlists.** Rejected because policy controls are not OS-enforced confinement; a bug in the main app or a compromised model context could bypass allowlists. The release gate explicitly requires privilege separation.

## Security and privacy impact

- The main app can eventually enable App Sandbox and be denied network access at the kernel level, closing a major exploit surface.
- Accessibility reads and shell execution are confined to dedicated processes with minimal privileges.
- Raw command output, AX element metadata, and filesystem evidence remain inside the helper until redacted/authorized by the main app before emission.
- The helper cannot broaden its own permissions; it is rebuilt/re-signed with fixed entitlements.
- Secrets are never passed to helpers except via the typed request envelope, and helper environments are restricted (`PATH=/usr/bin:/bin`, etc.).

## Operational impact

- Build pipeline must compile, sign, and package two additional helper executables.
- `scripts/build-app-bundle.sh` copies helpers into `AURA.app/Contents/Helpers/`.
- `scripts/codesign-adhoc.sh` signs helpers before the main app.
- `scripts/verify-signature.sh` verifies helper sandbox attestation and main-app entitlement absence.
- Helper processes are short-lived per request or long-lived per session; either path must enforce bounded output, timeout, and cleanup.

## Migration

1. Add `AuraAutomationHelper` and `AuraShellHelper` executable targets and entitlements.
2. Add `AuraHelperKit` IPC types in `AuraCore` (or extend existing shared types).
3. Refactor `AuraAutomation` and `AuraShell` to expose a protocol boundary with in-process and helper-backed implementations.
4. Update `AuraKernel` construction to select the helper-backed path only when configured.
5. Update `verify-signature.sh` assertions.
6. Add tests for helper IPC, attestation, and fallback behavior.
7. Once acceptance gate passes, switch the default to helper-backed and update `AURA.entitlements` to enable App Sandbox.

## Validation evidence

- `AuraAutomationHelper --attest-only` prints `sandbox-ok` and exits 0.
- `AuraShellHelper --attest-only` prints `sandbox-ok` and exits 0.
- `verify-signature.sh` passes for the release app bundle with the new helpers.
- `AuraAutomation` and `AuraShell` retain existing behavior via in-process fallback when helpers are not configured.
- Helper-backed path passes representative smoke tests with deterministic doubles.
- Full repository test suite passes with line coverage ≥70%.
- No new compiler warnings; strict concurrency warnings resolved.

## Consequences

- **Positive:** Main app becomes sandbox-ready; OS-enforced network confinement becomes achievable; release gate for privilege separation can be honestly claimed.
- **Negative:** Increases build complexity and helper process management overhead.
- **Risk:** Helper IPC latency may affect shell/AX responsiveness; must be measured and bounded. Risk is mitigated by keeping helpers warm-pooled or by using one-shot with tight timeouts, configurable per capability.

## Related

- `docs/decisions/ADR-007-native-macos-automation.md`
- `docs/decisions/ADR-008-typed-shell-process-runner.md`
- `docs/decisions/ADR-028-*.md` (verified plugin marketplace)
- `Sources/AuraAutomation/`
- `Sources/AuraShell/`
- `Sources/AuraPluginHost/`
- `Resources/AURA.entitlements`
- `Resources/AuraPluginHost.entitlements`
- `scripts/build-app-bundle.sh`
- `scripts/codesign-adhoc.sh`
- `scripts/verify-signature.sh`
- `Sources/AURA/AuraKernel.swift`
