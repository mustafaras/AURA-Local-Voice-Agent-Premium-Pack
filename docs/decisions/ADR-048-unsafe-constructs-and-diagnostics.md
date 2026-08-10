# ADR-048 — Bounded unsafe constructs and privacy-safe diagnostics

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-08-10 |
| **Owner** | AURA core team |
| **Track** | Repository hygiene H-006 |

## Context

The H-006 production inventory found five `try!` expressions, three
Accessibility `as!` casts, 21 `@unchecked Sendable` declarations/usages, two
`Task.detached` calls, and three direct `print()` calls. The audit also found
raw partial STT text and text-demo input in structured logger messages. These
constructs are not equivalent: some hide a fixed source invariant, while
others cross a callback or process boundary and need an explicit isolation
proof.

## Decision

1. Replace Accessibility force casts with an exact `CFGetTypeID` /
   `AXUIElementGetTypeID` check followed by `unsafeDowncast`. A mismatched
   Accessibility value returns the caller's existing safe outcome (`nil` or
   `false`); the bounded downcast is valid only after the type-ID proof.
2. Make fixed verdict/redaction regex initialization optional. Verdict parsing
   fails closed to `.unparseable`; redaction masks the OCR region as a generic
   secret if a built-in privacy pattern cannot initialize.
3. Wrap policy fingerprint encoding in an explicit invariant helper. The
   fingerprint consists only of repository-owned Codable value types; an
   encoding failure is a source regression and stops explicitly rather than
   hiding behind a forced throw.
4. Replace direct `print()` diagnostics with gated structured `AuraLogger`
   calls. Logs contain only bounded metadata (state, enum, confidence, and
   presence flags), never raw model reasons, error text, STT transcript, demo
   input, response summaries, ambient audio, or screen pixels. `AuraLogger`
   emits interpolated messages with `os.Logger` privacy `.private`.
5. Retain the lock/actor-based `@unchecked Sendable` and detached-task
   boundaries where their invariants are explicit and covered by focused
   tests. This includes the audio ring/task aggregates, callback PCM copy,
   native/mock STT engines and continuation boxes, STT router, system/mock/
   Chatterbox TTS boundaries, helper/plugin waiters and bounded collectors,
   plugin-host collector, and Conversation's locked task-value box. The
   existing ADRs remain authoritative for the established boundaries; this
   ADR records the H-006 inventory and the grouped acceptance decision.

## Alternatives considered

- Mechanically replacing all `@unchecked Sendable` and detached tasks with
  actors or inherited `Task` closures. Rejected: it would alter real-time
  callback, serial synthesizer, and test scheduling semantics without a
  proven replacement or a new architecture decision.
- Returning a dummy policy hash after encoding failure. Rejected: a fallback
  hash would weaken confirmation binding and could authorize the wrong plan.
- Logging raw input only behind an environment flag. Rejected: an opt-in flag
  is not a privacy proof and can still expose user or ambient transcript data.

## Consequences and residual risk

The audited force-failure/cast/print sites are now bounded or removed, and
diagnostic output is metadata-only at the call sites reviewed by H-006. The
remaining `@unchecked Sendable` declarations depend on lock coverage,
immutable-after-copy assumptions, platform callback behavior, or external
actor guarantees. Focused tests prove contract behavior but do not constitute
a complete race-detector or production hardware soak; broader concurrency,
CI, and complete test-matrix evidence remains a later hygiene concern. The
repository maintainer owns that residual review.

## Validation

- Strict production source build:
  `swift build --target AURA --build-path /tmp/aura-h006-source-build-final`
  with `-strict-concurrency=complete -warnings-as-errors`, exit 0.
- Focused wrapper evidence: AuraAgentTests 214/214, AuraScreenTests 36/36,
  AuraPolicyTests 19/19, AuraAutomationTests 6/6, AuraComputerUseTests 61/61,
  and AuraIntentTests 67/67.
- Source inventory after remediation contains no production `try!`, `as!`, or
  direct `print()` call.
