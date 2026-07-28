# ADR-024 — On-Device Chatterbox TTS Research and Prototype

- Status: Accepted
- Date: 2026-07-27
- Owners: GitHub Copilot
- Supersedes: —
- Superseded by: —

## Context

The AURA TTS roadmap, defined in `docs/subsystems/07_TURN_TAKING_AND_TTS.md`, specifies the following adapter priority:

1. **Chatterbox TTS** — preferred for natural prosody and explicit expressive control.
2. **Dia TTS** — experimental, used for advanced non-verbal expression when user-enabled.
3. **macOS System TTS (`AVSpeechSynthesizer`)** — always-available fallback.

`Sources/AURA/AuraKernel.swift` already defines a `makeTTSEngine(adapterChain:logger:)` factory that tries adapters in configured order. As of the current codebase it logs `chatterbox` and `dia` as not implemented and falls back to `SystemTTSEngine`. This ADR records the research findings for bringing Chatterbox on-device and the minimal prototype that implements the `TTSEngine` boundary without adding model weights to the repository.

### Research findings

**What Chatterbox is.** Chatterbox is a family of compact, open-weight neural text-to-speech models (e.g. `chatterbox-0.5B`) trained by Hume AI. The checkpoints are distributed in PyTorch/Safetensors format on Hugging Face and are typically used through the `transformers` Python ecosystem. They produce natural, controllable speech from text and optional speaker/style prompts.

**On-device inference options for Apple Silicon.** Three practical paths exist for running a non-Core-ML PyTorch/Safetensors model locally on macOS:

- **llama.cpp family** with an adapter. Chatterbox is a decoder-only or encoder-decoder transformer, not a Whisper/GPT-style autoregressive LM in the llama.cpp native sense. While community GGUF conversions may appear, the tokenizer, audio-codec head, and style-conditioning logic are not guaranteed to map cleanly to `llama.cpp` tensor naming. Relying on this would require a verified, upstream-supported conversion recipe.
- **mlx-swift / MLX Swift Examples.** Apple's MLX framework exposes a Swift API for running converted `safetensors`/`npz` weights on the Neural Engine / GPU / CPU. A Chatterbox port would require: (a) converting the PyTorch weights to MLX `safetensors`, (b) re-implementing the forward pass and audio codec (e.g. `encodec`-style RVQ) in Swift/MLX, and (c) integrating the tokenizer. This is feasible for a dedicated team but is a large engineering project and is beyond the scope of a safe, bounded prototype.
- **Process-based Python inference over XPC / local socket.** Keep the model weights and Python runtime outside the AURA process. A small, hardened helper (`AURATTSHelper`) loads the official `transformers`/`torch` inference stack, accepts text + style parameters over a local-only XPC/IPC channel, and streams audio back. This keeps the macOS app free of massive binary dependencies and lets the user manage the model file separately.

**Packaging constraints.** The user explicitly directed: *“Chatterbox model dosyaları repoya eklenmeyecek, sadece adapter/prototip.”* No model weights, converted weights, or third-party inference binaries are committed. The prototype must be buildable without the model present and degrade cleanly to `SystemTTSEngine` when the helper/model is unavailable.

## Decision

1. **Adapter-only prototype in the main app target.** Add `Sources/AuraAudio/ChatterboxTTSEngine.swift` conforming to `TTSEngine`. It implements the full contract (`start`, `speak`, `stopSpeaking`, `pauseSpeaking`, `resumeSpeaking`, `health`, `engineID`) but does **not** contain the model or perform real inference. Instead it exposes the boundary, reports readiness based on whether a configured helper/weights path exists, and emits typed `TTSChunk` markers that mirror the real streaming contract.
2. **External model execution is out of scope for this slice.** Real on-device Chatterbox inference (MLX port, Python helper, or community GGUF) is deferred until a later phase with explicit model-provenance, licensing, and security review.
3. **Factory wiring.** `AuraKernel.makeTTSEngine` is updated to recognize `chatterbox` in the adapter chain and return a `ChatterboxTTSEngine` instance when selected. Because the prototype reports `ready == false` unless a helper is configured, the chain will still fall back to `SystemTTSEngine` by default.
4. **No new external dependencies.** The prototype links only `AuraCore` and `Foundation`. No MLX, `onnxruntime-swift`, Python bridging, or network dependency is added now.
5. **Test coverage.** Unit tests verify the adapter contract, readiness behavior, and graceful fallback when the model is absent.

## Alternatives considered

- **Add `mlx-swift` and ship a real MLX Chatterbox inference engine now.** Rejected because the model weights are not in the repo, the forward-pass port is large and unverified, and the user explicitly scoped this to adapter/prototype only.
- **Embed a community GGUF conversion and use `llama.cpp` directly.** Rejected because no upstream-supported Chatterbox GGUF exists that we could verify, and inventing tensor mappings would violate the contract to never fabricate API/model capabilities.
- **Call a remote Chatterbox API endpoint.** Rejected because it conflicts with the privacy-first, on-device requirement and the current `No network entitlement is enabled` posture in `Resources/AURA.entitlements`.

## Security and privacy impact

- No text or model weights leave the repository.
- The adapter does not transmit `TTSPrompt.text` anywhere; the prototype synthesizes no real audio.
- Future helper-based designs must use a local-only IPC channel with sandbox validation and a user-controlled model-path setting before any text reaches the helper.

## Operational impact

- Build size unchanged.
- No new entitlements, permissions, or runtime resource usage.
- `ChatterboxTTSEngine` reports `ready: false` by default, so existing behavior (System TTS) is preserved.

## Migration

None. Existing callers of `TTSEngine` are unaffected. When a real Chatterbox implementation is added later it will replace the stub streaming logic in `ChatterboxTTSEngine.speak(_:)` while keeping the same public boundary.

## Validation evidence

- `ChatterboxTTSEngine` compiles as part of `AuraAudio` with Swift 6 strict concurrency.
- Unit tests assert: `engineID == "chatterbox"`, `start()` reports not-ready when no helper is configured, `speak(_:)` yields at least one progress marker and a `.complete` chunk, and `stopSpeaking()` terminates the stream promptly.
- `AuraKernel.makeTTSEngine` returns `ChatterboxTTSEngine` for adapter ID `"chatterbox"` and falls back to `SystemTTSEngine` when the prototype is not ready.

## Consequences

- AURA gains a concrete Chatterbox adapter placeholder that exercises the `TTSEngine` boundary and factory wiring.
- Real on-device neural TTS remains an explicit future phase with clear prerequisites: model file availability, verified licensing, chosen inference stack (MLX/Python helper/verified GGUF), and security review of the execution boundary.
- The codebase remains honest about what is implemented: the adapter boundary and fallback behavior, not a working neural voice.

## Related documents

- `docs/subsystems/07_TURN_TAKING_AND_TTS.md`
- `docs/decisions/ADR-005-conversation-turn-tts.md`
- `Sources/AuraCore/TTSEngine.swift`
- `Sources/AuraAudio/SystemTTSEngine.swift`
- `Sources/AURA/AuraKernel.swift`
