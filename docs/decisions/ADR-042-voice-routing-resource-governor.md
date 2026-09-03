# ADR-042 — Voice Routing and Local-Model Resource Governor

- **Status:** Accepted (system-TTS fallback scope; neural/wake deferred)
- **Owner:** R7 (second-pass)
- **Supersedes:** n/a
- **Related:** ADR-003 (test-only wake detector), ADR-045 (audit baseline)
- **Context files:**
  - `Sources/AuraCore/VoiceResourceGovernor.swift`
  - `Sources/AuraSTT/STTRouter.swift`
  - `Sources/AuraAudio/ChatterboxTTSEngine.swift`
  - `Sources/AuraAgent/OllamaAdapter_Preflight.swift`
  - `archive/runtime-completion/SECOND_PASS_OPEN_GAPS.md` (OPEN-08)

## Decision

Adopt a **local-first, fallback-preserving voice routing and resource
governor** for the 16 GB Apple Silicon primary profile:

1. **TTS chain:** `["chatterbox", "system"]`. The local Chatterbox Multilingual
   V3 adapter is the **primary voice**. The on-device system synthesizer is the
   fail-closed last resort when the Chatterbox helper, model, or reference
   recording is absent, warming, or failed. The system fallback auto-selects
   the best installed voice for the locale by platform quality; **no specific
   system voice (Kaan or Yelda) is hardcoded or preferred.** The neural adapter
   remains bounded by a private helper, timeout, output-size cap, private WAV
   output, and immediate fallback; its presence on disk is not by itself a
   readiness or release claim.
2. **STT routing:** Apple on-device Speech (Turkish/English general +
   command) via `STTRouter`, which reserves through the governor and fails
   closed on resource denial or engine-start failure. Code-switched English
   technical tokens are **excluded from the release scope** (SP-016,
   `EV-SP-016-20260822-BILINGUAL-QUALITY-03`).
3. **Resource governor:** `VoiceResourceGovernor` provides bounded
   reservations for `.stt`, optional `.ttsNeural`, and `.reasoning`, with
   memory-pressure and thermal admission, a failure circuit breaker, and
   idle-unload reservation control. Speech capture and system fallback remain
   available under critical pressure/thermal; other workloads are denied.
4. **Reasoning path:** the local Ollama adapter uses layered admission: the
   shared governor prevents cross-workload over-admission, while Ollama's
   `maxResidentModelBytes` budget and per-model eviction manage its own model
   residency. These are distinct controls, not a claim that one byte counter
   measures both pools.
5. **Wake word:** **explicitly excluded from the release scope** (SP-015,
   `EV-SP-015-20260822-WAKE-EXCLUSION-01`). Push to Talk is the only shipped
   activation; `MarkerWakeWordDetector` is test-only; the truthful UI states
   "no acoustic model is installed; Push to Talk remains available".

## Scope

In scope for the release:

- Push to Talk (always-available safe fallback), system TTS fallback,
  Turkish/English general + command on-device STT, TTS interruption/fallback/
  helper-crash/timeout, device/sleep/wake recovery, resource governor with
  memory-pressure/thermal/circuit/idle-unload.

Explicitly excluded (each documented above and in OPEN-08):

- Wake word and any acoustic wake model.
- Neural reference-voice, MPS qualification, and human listening acceptance.
- Code-switched English technical tokens in STT.
- Neural CPU/MPS first-audio and 8 h+ neural soak **release gates**. The
  release therefore makes no neural-quality or neural-performance claim.
- Physical speaker-to-microphone echo/self-trigger qualification, because the
  shipped activation is Push-to-Talk-only and the wake detector is excluded.

## Alternatives considered

| Alternative | Verdict | Reason |
|---|---|---|
| Remote/cloud voice and models | Rejected | Privacy-first; remote output and audio must not leave the device without an explicit user-controlled setting. |
| Wake word via licensed local model | Deferred (excluded) | No candidate qualified (FAR/FRR, TR support, noise/distance, license/hash, soak); authority forbids download/install in this pass. |
| MPS for neural TTS | Deferred outside release | No live qualification is claimed; the system voice is the release default. |
| No resource governor (admit all) | Rejected | 16 GB profile would be unprotected from co-resident STT + TTS + Ollama models. |
| Route all workloads through shared governor | Partial | STT and reasoning are admitted; optional neural TTS is guarded; screen/coding remain explicitly bounded exclusions. |

## Consequences

- **Positive:** Chatterbox is the primary voice; the always-available on-device
  system synthesizer is a truthful, auto-selected fail-closed fallback when the
  neural adapter is absent, warming, or failed; resource failure degrades to
  system voice rather than breaking conversation; no simultaneous large-model
  residency is silently assumed.
- **Negative:** wake word and code-switched technical tokens are not
  available; user-visible degraded health is required for each exclusion.
- **Risk disposition:** the neural co-residency and neural-latency risks remain
  governed; the shared governor still fails closed if an explicit future
  opt-in attempts admission.

## Expiry / revisit

This decision **expires** (must be revisited) if the user grants:
`download_models`, `install_dependencies`, or provider/telemetry authority,
or if a licensed wake candidate with Turkish support + FAR/FRR + soak is
supplied. Also revisit if the primary profile moves off 16 GB Apple Silicon or
if a measured co-resident soak shows the budgets need re-tuning.

## Evidence

- `EV-SP-015-20260822-WAKE-EXCLUSION-01` — wake exclusion, inventory, truthful UI.
- `EV-SP-016-20260822-BILINGUAL-QUALITY-03` — Turkish/English general+command pass, code-switch exclusion, fail-closed regression.
- `EV-SP-017-20260823-GOVERNOR-IDLE-UNLOAD-01` — idle-unload control + tests.
- `EV-SP-017-20260823-LIVE-SYSTEM-TTS-01` — direct live system-TTS latency and interruption evidence.
- `EV-SP-017-20260823-RESOURCE-SCOPE-02` — 16 GB host/resource observation and explicit neural/wake/system-only scope.

## Acceptance record

The user explicitly requested completion of all SP-017/OPEN-08 gates in the
current session, and later directed that Chatterbox be the primary voice with
the system synthesizer only as a fail-closed last resort. That instruction
accepts this bounded routing decision: `["chatterbox", "system"]`, with no
specific system voice hardcoded or preferred; neural TTS quality and wake word
remain deferred and must not be displayed as ready. Revisit requires new
live evidence and an explicit scope change.
