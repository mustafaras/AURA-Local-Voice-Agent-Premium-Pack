# Wake-Model Inventory

> **Purpose:** SP-015 (`OPEN-08`/R7) requires an explicit inventory of every
> wake-word candidate considered and its qualification disposition, so the
> release scope decision is evidence-backed and never inferred from a type,
> fixture, or historical ledger line.
>
> **Authority note:** this inventory documents **candidate availability and
> disposition only**. Provisioning a candidate is separately gated by the
> session authority (`download_models`, `install_dependencies`,
> `provider_accounts`). As of the SP-015 decision, `download_models=false` and
> `install_dependencies=false`, so no external wake-word asset was downloaded or
> installed for this decision.

## Inventory table

| Candidate | Source / license | Turkish | On-device | Model artifact present? | Hash / license evidence | Disposition |
|---|---|---|---|---|---|---|
| (none provisioned) | n/a | n/a | n/a | **No.** No `.mlmodel`/`.mlmodelc`/`.tflite`/wake `.onnx`/`.bin` model is bundled or present for wake-word use. | n/a | **Excluded from release scope** — no licensed local candidate is provisioned to qualify. | Open (exclusion) |
| `MarkerWakeWordDetector` | In-repo test fixture (`Sources/AuraAudio/WakeWordDetector.swift`) | n/a (synthetic 1 kHz tone) | n/a | Test-only source (not a model asset). | Explicitly marked **test-only** in ADR-003 and capability-matrix notes. | **Test-only; NOT a production candidate.** | Test-only |

## On-disk artifact scan (2026-08-22)

`find . -type f \( -name '*.mlmodel' -o -name '*.mlmodelc' -o -name '*.tflite'
-o -name '*.onnx' -o -name '*.bin' \)` returned only the **Chatterbox Python
virtualenv's ONNX library conformance fixtures** under
`Runtime/chatterbox/.venv/lib/python3.11/site-packages/onnx/backend/test/data/...`
These are third-party library test data (ONNX operator fixtures), **not wake-word
models**, and are not wired to any detector.

## Production wake detector

- `Sources/AURA/AuraKernel_Construction.swift` wires
  `WakeWordPipeline(wakeDetector: DisabledWakeWordDetector(), ...)`.
- `DisabledWakeWordDetector` **cannot detect** (returns `detected:false` always),
  so production activation is **Push-to-Talk-only**; it is not a degraded-ready
  signal.
- The capability matrix row `voice.wake_word` is
  `registered_disabled` / `test_only` / `unit_only`.

## Decision disposition (SP-015)

- **No licensed local wake-word candidate is provisioned or bundled.**
- Authority for this pass forbids `download_model` and `install_dependencies`,
  so no candidate can lawfully be obtained or evaluated here.
- Under Procedure step 3 of SP-015, the decision is **explicit wake-word
  exclusion from release scope**: production remains Push-to-Talk-only and the
  capability/UI/ADR scope is updated truthfully. No wake-word claim is made.
