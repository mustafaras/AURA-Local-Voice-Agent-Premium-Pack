# EV-SP-018-20260823-PRODUCTION-REFERENCE-WIRING-01

| Field | Value |
|---|---|
| Evidence ID | `EV-SP-018-20260823-PRODUCTION-REFERENCE-WIRING-01` |
| Prompt / gap | SP-018 / OPEN-09 / R8 |
| Timestamp | 2026-08-23T16:47:04Z |
| Branch / commit | `main`; `HEAD == origin/main == e5835e983a9a98e3a1a5a955ef60a22a1fd6c932`; SP-018 edits are uncommitted and expected |
| Environment | macOS 27 on Apple Silicon; repository SwiftPM production build |
| Procedure | `swift build --build-path /tmp/aura-sp018-final-build`; `git diff --check` |
| Result | Production composition compiled successfully and the diff check passed. `AuraKernel` supplies a typed read-only reference snapshot to `IntentEngine`; the engine assembles bounded dialogue/file/tool/workspace/task/backend candidates and passes them to `ContextBuilder` and `ReferenceResolver`. |
| Artifact / hash | `Sources/AURA/AuraKernel_Construction.swift` SHA-256 `a2b38a03eb3701c8777e49eec546d7c1228ebc2eddb81e9c802f1c0fd2a70b8a`; `docs/subsystems/22_CONTEXT_RECONSTRUCTION.md` SHA-256 `097be8a70e257c5e09da9411856f3ff014e02e2eef5d7110f03900e3232977c4` |
| Evidence class | Direct repository production-composition build/source evidence; deterministic execution remains separately recorded below. |
| Scope | Local, bounded, provenance-aware reference wiring only. No provider, remote transport, app launch, TCC mutation, or external write was performed. |
| Limitations | The application was not launched under this prompt's authority, so this item does not claim user-present UI, restart, physical-device, or external-provider acceptance. |
