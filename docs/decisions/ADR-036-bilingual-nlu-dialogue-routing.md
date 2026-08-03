# ADR-036 - Bilingual NLU and Dialogue Routing

- Status: Accepted for R2 implementation
- Date: 2026-08-02
- Owners: GitHub Copilot
- Supersedes: -
- Superseded by: -

## Context

AURA's previous intent layer used a narrow English prefix grammar and routed ordinary conversation to a fixed acknowledgement. R1 established the immutable turn context, truthful runtime health, confirmation transaction, and response-plan contracts needed to add a language-aware dialogue path without giving model output authority.

## Decision

1. The input path is layered: deterministic bilingual fast path first, schema-validated local structured NLU refinement second, and typed dialogue clarification or reasoning response last.
2. `DialogueLanguage` and `DialogueAct` are typed metadata. Language detection is deterministic and may return Turkish, English, mixed, or unknown. It never authorizes an action.
3. Known safe local commands may execute only when the deterministic classifier resolves a registered typed capability and its required slots. Turkish aliases, application morphology, code-switching, and technical terms are accepted without guessing unknown applications or executables.
4. Structured NLU output is provider-neutral at the IntentEngine boundary. A local Ollama adapter may propose language, dialogue act, capability identifier, confidence, and ambiguity reason through a bounded JSON schema. The proposal is independently parsed. Any execute/delegate/confirm proposal without a deterministic typed slot plan is converted to `.unknown` and clarification; raw model output never reaches ToolRouter execution.
5. Ordinary conversation is handled by `DialogueEngine`. It sends bounded user text plus bounded provenance-bearing context to the selected local reasoning backend. Context is explicitly labeled as untrusted data, and the model is instructed not to execute tools or claim side effects. Empty, malformed, overlong, or unavailable responses degrade to an explicit language-preserving message.
6. Response plans carry detected language and the conversation state machine selects the corresponding TTS locale. Clarification questions have Turkish, English, and mixed-language forms.
7. Ollama remains loopback-only, policy-gated, cloud-disabled by default, thermal/memory bounded, and optional. Model unavailability is visible through honest degraded dialogue rather than a fabricated substantive answer.

## Alternatives considered

- Let the model emit executable capability arguments directly. Rejected because model output is untrusted data and typed policy/slot validation must remain the execution boundary.
- Replace the deterministic fast path with an LLM classifier. Rejected because emergency and high-frequency local commands need reproducible low-latency behavior and must work when the model is unavailable.
- Keep the fixed acknowledgement when Ollama is unavailable. Rejected because it hides degraded behavior and makes an ordinary question appear handled.
- Send the entire memory/context bundle to the model. Rejected because context must remain bounded, provenance-aware, and privacy-minimal.

## Security and privacy impact

The dialogue prompt contains bounded approved context only; source identifiers and authority are retained for inspection. Retrieved context is labeled data and never becomes policy authority. No secrets, raw screenshots, ambient audio, or unredacted private content are intentionally added to the dialogue prompt. The structured NLU boundary rejects unknown schema values, invalid confidence, unknown language/act, and action proposals without typed slots.

## Operational impact

`IntentEngine` accepts an optional provider-neutral structured NLU backend. `DialogueEngine` accepts an optional reasoning backend and returns a typed response with model ID, degradation state, language, act, and source IDs. `ToolRouter` keeps a safe backend-free default for tests and uses the production engine from `AuraKernel`.

## Migration

Existing `TypedIntent`, `ResponsePlanEvent`, and `Conversation` initializers remain source-compatible through additive defaults. Existing deterministic tests continue to use no model backend. Existing configuration files decode with the previous values; Turkish aliases are defaults and explicit user sets still override them.

## Validation evidence

- `AuraIntentTests` focused run passes 44/44, including Turkish morphology, mixed-language ambiguity, polite paraphrases, golden-corpus matching, bounded dialogue output, honest degradation, slot expiry, and model action proposal rejection.
- `AuraAgentTests` focused run passes 208/208, including Ollama structured NLU decode/rejection and existing adapter/orchestration/conversation coverage.
- `AURAIntegrationTests` focused run passes 17/17 after production coordinator/kernel wiring.
- Full R2 regression passes 20/20 bundles and 695/695 tests in the current-tree run at `/tmp/aura-r2-after-gap-fixes`. Live Ollama first-token/quality evidence and authorized hardware demonstration remain open before R2 completion.

## Consequences

- Positive: ordinary questions no longer fall through to a production `Got it.` placeholder when the local reasoning backend is available; unavailable models are reported honestly.
- Positive: Turkish, English, and mixed-language metadata is carried through typed intent and response/TTS routing.
- Positive: model NLU proposals are constrained to non-executable typed decisions until a later capability/planner track supplies validated slots.
- Limitation: R2 still needs a larger golden corpus, paraphrase/ASR-error measurements, live Ollama residency/quality measurements, and authorized hardware demonstrations before completion.
