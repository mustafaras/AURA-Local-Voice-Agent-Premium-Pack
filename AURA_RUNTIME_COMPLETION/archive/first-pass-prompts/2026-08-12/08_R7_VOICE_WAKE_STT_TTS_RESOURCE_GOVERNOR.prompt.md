# R7 — Wake Word, STT/TTS Routing, and Resource Governor Prompt

Execute after R2. Preserve Push to Talk as the always-available safe fallback.

## Mission

Complete the live voice experience: reliable bilingual transcription, optional real local wake word, robust turn completion, interruption, TTS fallback, sleep/device recovery, and model resource governance suitable for a 16 GB Apple Silicon Mac.

Do not enable or claim a wake-word or neural-voice capability that has only synthetic, deterministic, or incomplete live evidence.

## Required context

Read:

- `Sources/AuraAudio`, `Sources/AuraSTT`, conversation and TTS implementations;
- voice configuration and permission coordinator;
- Chatterbox helper/model/runtime docs and evidence;
- audio/STT/TTS/integration tests;
- current official Apple Speech/AVFoundation documentation;
- candidate wake-word and local STT engine official docs/licenses;
- ADR-042 proposal.

## A. Voice operating modes

Implement and expose:

- Push to Talk;
- optional wake word;
- optional bounded conversational continuation window;
- privacy/paused mode;
- emergency stop/cancel.

Every mode must have a visible state and clear microphone behavior. Wake word and continuation are opt-in.

## B. Real wake-word evaluation and integration

Select a production candidate only after evaluating:

- offline/local operation;
- Turkish phrase support;
- Apple Silicon support;
- license/distribution compatibility;
- model size and update integrity;
- false-accept/false-reject performance;
- noise and distance robustness;
- TTS/media self-trigger resistance;
- energy/CPU impact;
- debounce and privacy behavior.

Replace or isolate `MarkerWakeWordDetector` as test-only. If no candidate meets gates, ship Push-to-Talk-only and mark wake word excluded rather than degraded-ready.

## C. STT router

Retain Apple on-device Speech as one adapter. Add a routing layer that may use a local Whisper-family or equivalent engine for:

- Turkish/English code-switching;
- offline fallback;
- unsupported/unavailable Apple locale/service;
- technical vocabulary;
- quality-based fallback.

The router must:

- expose real engine health;
- normalize confidence/segments;
- support cancellation;
- preserve audio privacy;
- avoid duplicate ingestion/results;
- record actual engine/model/version;
- use bounded user vocabulary;
- respect resource/thermal budgets.

## D. Turn completion

Combine:

- VAD silence;
- stable/final STT status;
- incomplete sentence/semantic continuation heuristic;
- deterministic command completion;
- maximum listen bound;
- explicit user continuation.

Do not end every turn solely because one engine emits a final segment if the utterance is incomplete.

## E. Barge-in and echo/self-trigger protection

- TTS yields immediately to authorized user speech.
- Assistant audio must not retrigger wake detection or be transcribed as user speech.
- Pause/resume/stop commands remain deterministic.
- Cancellation must stop audio/model work promptly.

## F. TTS chain

Keep system Yelda as the reliable local fallback.

For neural TTS:

- maintain owned/consented reference requirement;
- preserve watermarking/integrity safeguards;
- fix or explicitly exclude MPS if unstable;
- measure first-audio and synthesis factor;
- cache only safe frequent prompts;
- bound helper memory, output, lifetime, and cleanup;
- degrade immediately to system voice on health/latency/resource failure;
- never speak secrets.

## G. Resource governor

Coordinate STT, NLU/reasoning, TTS, screen vision, and coding models.

Required controls:

- resident-memory budget;
- model priority and preemption;
- idle unload;
- thermal and memory-pressure response;
- circuit breaker after repeated failure;
- background vs foreground task priority;
- no simultaneous large-model residency unless measured safe;
- user-visible health/degraded state.

## H. Recovery

Handle:

- sleep/wake;
- input/output device changes;
- headset connection;
- permission revocation;
- recognizer unavailable;
- model/helper crash;
- audio interruption;
- app restart.

## Evaluation

Create reproducible datasets/protocols for:

- Turkish, English, mixed technical speech;
- names, paths, repositories, commands;
- quiet/noisy/far-field conditions;
- wake FAR/FRR;
- first partial/stable latency;
- WER/entity error;
- turn-end latency;
- TTS first audio and quality;
- barge-in latency;
- CPU/energy/memory/thermal behavior;
- 8-hour or longer soak.

Clearly distinguish synthetic audio, recorded consented audio, and live human evaluation.

## Tests

Required:

- engine routing and health;
- Apple/local fallback;
- mixed-language results;
- cancellation and duplicate-result prevention;
- wake debounce/self-trigger/noise;
- turn completion/incomplete utterance;
- TTS fallback/helper crash/timeout;
- resource budget/preemption/thermal circuit;
- sleep/device/permission recovery;
- privacy retention;
- model hash/license/config validation.

## Completion gate

R7 is complete only when Push to Talk remains stable, bilingual STT meets quality targets, turn-taking/barge-in/recovery are live-verified, resource governance protects 16 GB hardware, and wake/neural TTS are either genuinely live-qualified or explicitly excluded with truthful UI.

Accept ADR-042, update capability/evidence/risk/state/ledger/handoff, unblock R9, and run closeout.
