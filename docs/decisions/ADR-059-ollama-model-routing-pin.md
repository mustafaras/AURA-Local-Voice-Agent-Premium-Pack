# ADR-059: Ollama Model Routing — an Explicit Pin and Per-Request Generation Knobs

**Status:** Accepted (owner-directed, 2026-09-12)
**Supersedes:** nothing. Extends ADR-055 (cloud inference enabled by owner direction).

## Context

Two defects were found while investigating an owner-reported Ollama rate limit.
Both are grounded in measurements taken against the live daemon on this host.

**1. Routing silently collapsed onto cloud models.** `OllamaModelRegistry.route`
ends with "choose the smallest `sizeBytes`", a rule written to protect resident
memory on the 16 GB target profile. Measured from this host's `/api/tags`:

| reported size | kind | model |
| --- | --- | --- |
| 293 B | cloud | `glm-5.3:cloud` |
| 317 B | cloud | `glm-5.3-flash:cloud` |
| 1,153,529,984 B | local | `MiniCPM5-1B…Q8_0` |
| 5,347,929,166 B | local | `granite4.2:8b` |

`:cloud` entries report a placeholder of a few hundred bytes. With
`allowCloudModels` defaulting to `true`, the size rule therefore selects a cloud
model **every time**, regardless of which local models are installed: 293 beats
1.15 billion on every comparison. The rate limit was not incidental; it was the
default routing path. Size stopped expressing memory pressure the moment cloud
models were registered.

**2. A reasoning model with no token budget returns empty answers.** AURA sent
no `options` at all — the request body had no field for them — so it could
neither bound nor shape generation. Measured against `glm-5.3-flash:cloud` with
the same prompt:

| request | thinking | response | outcome |
| --- | --- | --- | --- |
| `num_predict: 4096`, reasoning default | 12,352 chars | **0 chars** | `done_reason: length` — no answer |
| `think: false`, `num_predict: 4096` | 0 | 12,622 chars | reasoning text leaks *into* the answer, in English |
| `think: "low"`, `num_predict: 4096` | 0 | 10,679 chars | clean, complete Turkish answer |

AURA never reads Ollama's `thinking` field, so every token spent there is spent
on output the product discards — and on a complex prompt that was the entire
budget.

## Decision

1. **`OllamaConfiguration.preferredModel`** names the model to route to, by its
   exact `/api/tags` name. Default `glm-5.3-flash:cloud` (owner-directed).
   Empty means "no pin — route by capability".
2. **The pin is applied after every policy filter, never before.** It selects
   *within* what policy already permits and can never widen it: pinning a
   `:cloud` model while `allowCloudModels` is `false` matches nothing and falls
   through to the heuristic. A pin naming a model this host does not have also
   falls through — a stale pin cannot take the assistant offline.
3. **`responseTokenBudget`** (default 4096) is sent as `options.num_predict`,
   and **`thinkingEffort`** (default `"low"`) as `think`.
4. **Both apply to free-text answers only.** A schema-constrained request (one
   carrying a `format`) keeps exactly the shape it has always sent: truncating a
   JSON document at a token cap yields an unparseable answer, and that path is
   load-bearing for classification and summarization. The rule is a pure
   function, `URLSessionOllamaAPIClient.generationKnobs`, pinned by test rather
   than asserted in prose.

## Alternatives considered

- **Set `allowCloudModels = false`.** Stops cloud routing, but the size rule
  then selects the *smallest local* model — the 1.08B MiniCPM — for a bilingual
  assistant. It also contradicts ADR-055. Rejected: it fixes the symptom by
  degrading the answer.
- **Correct the size heuristic** (treat a placeholder size as unknown and rank
  cloud last). Attractive, and still worth doing, but it only re-orders an
  implicit choice. The owner asked for a specific model; naming it is the honest
  encoding of that requirement. The heuristic's hazard is now pinned by test
  (`ollamaRegistrySizeRuleResolvesToCloudBecauseCloudReportsPlaceholderSize`) so
  the next change to it cannot pass unnoticed.
- **`think: false`.** Measured to move reasoning into the answer body rather
  than suppress it — on this model it produces English reasoning prose where a
  Turkish answer belongs. Rejected on evidence.
- **Raise the budget only.** Measured to produce 12,352 characters of discarded
  reasoning and an empty answer. Rejected on evidence.

## Security and privacy impact

The pin cannot enlarge the set of reachable models: it is applied after the
`allowCloudModels` filter, and a test asserts that pinning a cloud model under a
local-only policy returns the local model. Cloud inference remains governed by
ADR-055 and still runs through the `.agentOllamaCloudInference` confirmation
challenge. This ADR makes an existing default *visible* rather than changing
what is permitted: routing already went off-device on every request; nothing
here newly enables that, and the size-rule finding is recorded precisely so the
privacy posture is not mistaken for what the code comment implied.

## Operational impact

Answers are longer and slower by design. Measured end-to-end in the running app:
thinking 20 s, speaking 56 s, return to idle at 80 s for a seven-part answer.
The 4096-token budget is a ceiling, not a target, and is configurable.

## Migration

All four fields are additive with defaults, decoded with `decodeIfPresent`, so
an existing configuration file without them keeps working and receives the new
defaults. `mergedWithDefaults` passes `preferredModel` and `thinkingEffort`
through unchanged: an explicitly empty value is a deliberate choice, not a
missing one, and merging must not silently re-pin it.

## Validation evidence

- Live daemon, before any code change: `glm-5.3-flash:cloud` HTTP 200, 1.57 s,
  correct Turkish; the three-row `think` comparison table above.
- `AuraAgentTests` 247 tests / 9 suites, exit 0 (243 before; +4 knob tests, and
  5 routing tests added earlier in the same pass).
- Full suite `./scripts/aura-test.sh` — 22/22 PASSED, `Failed bundles: 0`,
  exit 0.
- Release bundle rebuilt, stable-signed, `codesign --verify --deep --strict`
  exit 0.
- End-to-end in the running app: a seven-region Turkish answer rendered in the
  transcript, read back through the acceptance driver at 78 lines / 5,779
  characters — replacing the pre-change degraded path
  ("Yerel yanıt modeli şu anda kullanılamıyor").

## Consequences

The routing decision is now legible: one named model, one place to change it.
The size heuristic survives as the fallback, with its cloud-placeholder hazard
documented and pinned. Two defects remain open and are recorded rather than
fixed here: the assistant's answer is rendered twice on the conversation surface
(transcript bubble and the `lastOperationMessage` "Plan / Doğrulama" panel), and
runtime-produced English reason strings ("speech complete", "response plan has
spoken response") still reach a Turkish UI unmapped.
