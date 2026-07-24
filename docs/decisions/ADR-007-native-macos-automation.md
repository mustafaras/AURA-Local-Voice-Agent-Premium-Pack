# ADR-007 — Native macOS Automation Integration

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-07-25 |
| **Author** | GitHub Copilot |
| **Supersedes** | — |

## Context

Phase 6 of the AURA implementation roadmap requires native macOS integration for desktop control: application discovery, launch/activate/hide/quit, Accessibility-based observation, permission health, stale element handling, and safe degradation. The system must remain local-first, privacy-preserving, and policy-controlled. Every action must be observable through the typed event bus and auditable without exposing raw screen content or secrets.

## Decision

1. **Scope of this phase.** Implement the foundational native macOS automation layer inside the existing `AuraAutomation` target. This phase covers:
   - Application discovery and lifecycle (launch, activate, hide, quit) via `NSWorkspace` and `AppKit`.
   - Accessibility permission health detection and safe degradation.
   - A typed Accessibility observer that reads application/window/element metadata, validates element identity, and treats stale references as expected failures.
   - Typed event payloads for automation observations and actions.
   - Configuration blocks for automation permissions and redaction rules.

2. **No screen capture in this phase.** Screen capture via `ScreenCaptureKit` and redaction heuristics are explicitly out of scope for Phase 6. They are reserved for a later phase with dedicated permission, redaction, and retention design.

3. **Layered architecture.** `AuraAutomation` exposes:
   - `ApplicationController` — synchronous/off-main discovery and lifecycle calls wrapped in actor-isolated async methods with timeouts.
   - `AccessibilityHealth` — checks Accessibility trust state and produces human-readable guidance.
   - `AccessibilityObserver` — reads focused application/window metadata and validates element identity before returning observations.
   - `NativeMacOSAutomation` actor — composes the above, emits events, and exposes the public API.

4. **Event-driven observability.** All lifecycle and observation results emit typed events through `AuraEventBus`. Payloads live in `AuraCore` so that `AuraAgent`, `AuraPolicy`, and other targets can subscribe without importing `AuraAutomation`.

5. **Policy alignment.** `NativeMacOSAutomation` does not execute actions on its own. It provides the primitives that tool adapters will later route through `PolicyEngine`. The phase adds no policy enforcement inside `AuraAutomation`; it relies on the existing deny-by-default policy engine in `AuraPolicy`.

6. **Safe degradation.** Every Accessibility call runs with a bounded timeout. If permission is denied, the target app is not running, or the element reference is stale, the call returns a structured `AuraError.automationError` and an event is emitted. No retry loop nags the user.

7. **Strict concurrency.** All mutable state lives inside actors. `NSWorkspace` and `AppKit` calls are dispatched off the real-time audio path. `AccessibilityObserver` does not perform observation work on the audio actor.

8. **Testing strategy.** Accessibility calls are wrapped behind protocols so tests can inject deterministic mock states. No test depends on live Accessibility permission being granted.

## Consequences

- **Positive:** AURA now has a typed, testable, actor-isolated native macOS automation foundation that respects permission state and degrades safely.
- **Negative:** This phase does not implement actual screen capture, keyboard/pointer injection, or application-specific adapters (VS Code:, Terminal, browser, etc.). Those require additional ADRs and permission handling.
- **Risk:** `NSWorkspace`/`AppKit` APIs may change in future macOS releases; APIs used here are long-standing and verified against the macOS 27 baseline, but availability annotations may be needed later.

## Related

- `prompts/implementation/06_06_NATIVE_MACOS.prompt.md`
- `docs/subsystems/10_COMPUTER_USE.md`
- `docs/subsystems/11_MACOS_ACCESSIBILITY.md`
- `docs/subsystems/12_SCREEN_CONTEXT.md`
- `docs/security/25_PERMISSION_SYSTEM.md`
- `Sources/AuraCore/AuraConfiguration.swift`
- `Sources/AuraCore/AutomationEventPayloads.swift`
- `Sources/AuraAutomation/NativeMacOSAutomation.swift`
- `Tests/AuraAutomationTests/NativeMacOSAutomationTests.swift`
