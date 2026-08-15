# EV-SP-003-20260815-INJECTION-COVERAGE-18

**Session:** AURA-SP-003-LIVE-DIALOGUE-20260815
**Timestamp:** 2026-08-15T18:55:00Z
**Branch / commit:** `main`, on top of `6a710b1`
**Environment:** macOS 27 / Apple Silicon arm64 / Swift 6.4 / CommandLineTools
**Evidence class:** Source audit plus deterministic regression evidence.

## Purpose

Follow-up to SP-003 closure, on explicit user instruction to resolve the forwarded residual
risks. Covers `RISK-INJECTION-COVERAGE-NON-DIALOGUE` (closed) and records the verification
performed for `RISK-SP-003-MODEL-LATENCY`. The other two forwarded risks are dispositioned in
`RISK_REGISTER.md` as accepted-not-fixed and not-closable, with reasons.

## Audit: every model-prompt construction site

| Site | Interpolated content | Provenance | Screened before? | Now |
|---|---|---|---|---|
| `DialogueEngine.makePrompt` | `DialogueContextItem.summary` | retrieved/remembered | No (fixed in `-17`) | Screened |
| `MultiAgentOrchestrator.reviewerPrompt` | repository `diff` | `.repositoryFile` | **No** | Screened |
| `MultiAgentOrchestrator.reviewerPrompt` | `validation.outputTail` | `.terminalOutput` | **No** | Screened |
| `MultiAgentOrchestrator.implementerPrompt` | planner model `plan` | `.agentToolOutput` | **No** | Screened |
| `MultiAgentOrchestrator.correctorPrompt` | reviewer model `feedback` | `.agentToolOutput` | **No** | Screened |
| `MultiAgentOrchestrator.correctorPrompt` | `validation.outputTail` | `.terminalOutput` | **No** | Screened |
| `OllamaTaskRunner` (classify/summarize/reason) | `request.objective` | `.userUtterance` | n/a | Correctly unscreened — authoritative |
| `IntentEngine.makeStructuredNLUPrompt` | raw user utterance | `.userUtterance` | n/a | Correctly unscreened — authoritative |
| `ProductivitySecurity` | external content | various untrusted | Yes | Unchanged |

The orchestrator finding is material: a repository diff or a crafted test-output tail could
instruct the reviewer model directly, including into emitting a forged `VERDICT: APPROVE` — the
exact token the orchestrator parses to decide whether a change is accepted. Content that carries
authority (the live user's own words) is deliberately left unscreened; a user cannot inject into
their own request, and screening it would corrupt legitimate instructions.

## Change

- New `Sources/AuraSecurity/PromptInjectionScreen.swift`: one enforcement point wrapping
  `PromptInjectionClassifier`, exposing `screen(_:provenance:)` and
  `screenReporting(_:provenance:)`. Blocked spans are replaced by a visible withheld marker
  rather than dropped silently, so a trace shows that a source was consulted and refused. A
  reviewer whose diff is withheld therefore cannot approve on faith — it fails closed.
- `MultiAgentOrchestrator_Prompts.swift`: screens `diff`, `validation.outputTail`, `plan` and
  `feedback` at their correct provenances; imports `AuraSecurity` (already a declared dependency
  of `AuraAgent`).
- `DialogueEngine.swift`: refactored onto the shared screen instead of holding its own
  classifier, so both paths share one policy. The original defect was a detector that existed but
  was never called; duplicated policy is precisely how that recurs.

## Verification

- New `Tests/AuraAgentTests/MultiAgentOrchestratorPromptInjectionTests.swift`, 6 tests: a
  poisoned diff, poisoned validation output, poisoned reviewer feedback and a poisoned plan are
  each withheld from their prompt; clean content of all four kinds passes through byte-identical;
  and a withheld diff still leaves the fail-closed `VERDICT: REQUEST_CHANGES` instruction intact.
- `AuraAgentTests`: **220/220 passed** (214 before, +6).
- Full sweep: **21/21 bundles, 0 failed**.

## Latency bound verification (`RISK-SP-003-MODEL-LATENCY`)

No code change can make a local 8B Q4_K_M model faster, so the claim tested was the weaker,
checkable one: that slow inference is bounded and degrades honestly rather than hanging.
`ConversationConfiguration.thinkTimeoutSeconds` defaults to 90 s and is genuinely enforced by
`scheduleTimeout(for: .thinking,…)` in `Conversation_State.swift` and
`Conversation_Commands.swift`; `OllamaConfiguration.requestTimeoutSeconds` defaults to 120 s.
Every measured turn (19.8–36.1 s) sat well inside the think budget. The risk stays open as an
observation, not a defect.

## Scope and limitations

- Rule-based screening is deterministic and auditable, not exhaustive; novel phrasings or
  obfuscation may evade the fixed rule set.
- Nothing mechanically forces a *future* prompt-construction site to use `PromptInjectionScreen`.
  That is the remaining exposure for this risk and is a review/lint concern rather than a live
  defect.
- `RISK-SP-003-NLU-DOWNGRADE-VARIANCE` was deliberately **not** fixed: every available fix either
  breaks the tested safety property in
  `structuredModelActionProposalCannotBecomeExecutableIntent` or doubles an already-slow turn.
  Reasons are recorded in `RISK_REGISTER.md`.
- `RISK-SP-003-LIVE-VOICE-RESIDUAL` cannot be closed in this environment; the user is
  speech-disabled and no code change substitutes for the hardware gate.

## Verdict

`RISK-INJECTION-COVERAGE-NON-DIALOGUE` is closed for every model-prompt site currently in the
codebase, with the orchestrator's four previously-unscreened surfaces fixed and regression-tested.
`RISK-SP-003-MODEL-LATENCY` is verified bounded. The remaining two risks stay open with explicit,
recorded reasons rather than being reported as resolved.
