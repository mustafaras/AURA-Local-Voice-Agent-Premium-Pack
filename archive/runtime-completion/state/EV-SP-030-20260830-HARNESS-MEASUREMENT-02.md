# EV-SP-030-20260830-HARNESS-MEASUREMENT-02

**Evidence ID:** EV-SP-030-20260830-HARNESS-MEASUREMENT-02
**Track:** SP-030 / R12 / OPEN-13
**Type:** Measurement (class: `deterministic_harness`) — local first-token latency, **lower bound only**
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty, uncommitted)
**Environment:** macOS 27.0 arm64, Apple Silicon; Ollama on loopback `127.0.0.1:11434`
**Session:** AURA-SP-030-BETA-EVIDENCE-20260830

## What was measured

Time from HTTP request to the **first streamed token** from a warm, resident,
genuinely local Ollama model, over loopback, 30 samples after a discarded warmup.

| p50 | p95 | p99 | min | max | n |
|---|---|---|---|---|---|
| 38.9 ms | 40.1 ms | 41.1 ms | 38.6 ms | 40.8 ms | 30 |

Model: `hf.co/GnLOLot/MiniCPM5-1B-Claude-Opus-Fable5-V2-Thinking-GGUF:Q8_0`
(1.3 GB resident, 100% GPU, confirmed local — not a `:cloud` proxy).

## What was NOT measured — read this before using the numbers

**This is a lower bound on `local_dialogue_first_token_ms`, not the metric itself.**
It covers only the model backend leg. It **excludes** AURA's in-app routing, NLU,
policy evaluation, and UI render — every one of which sits between the user's
input and the first token they actually see. The user-observed value is strictly
larger and remains **unmeasured**.

**No target is asserted and no pass/fail is claimed.** `target_ms` is deliberately
left `null` so the record cannot be read as an SLO being met.

**The figure is model-dependent.** A 1B model was used because the larger local
model failed (below). An 8B-class figure would very likely be materially higher.

## Incidental finding — `granite4.2:8b` does not load

`granite4.2:8b` (5.3 GB, genuinely local) was the first choice precisely because
it is more representative of a real dialogue model. It **failed to return a first
token within a 900-second warmup**, twice, while `ollama ps` showed no resident
model — i.e. the request never reached a loaded model. The daemon itself is
healthy: the 1.3 GB model loaded and answered in ~1.2 s immediately afterwards, so
this is model-specific, not an Ollama or environment fault.

This is recorded as an observation, not an SP-030 gate item. It is worth the
release owner's attention: if the product would route to an 8B-class local model,
that model currently does not serve on this machine.

## Method

Streaming `POST /api/generate` with `num_predict: 8`, timing to the first chunk
carrying a non-empty `response` field. Warmup call discarded so cold model load is
excluded from the sample. Percentiles computed over the 30 retained samples.

## Falsifiers

Any claim that this measures the full in-app dialogue path, that a latency target
was met, that it is a live user-present beta sample, or that it generalizes to the
model the product routes to, would falsify this record.

## Net effect on SP-030

`dialogue_first_token` moves `not_measured` → `measured` with an explicit
lower-bound limitation and **no target**. `ptt_ack` and `stt_partial` remain
`not_measured`. The completion gate is **not** met; SP-030 stays `in_progress`.
