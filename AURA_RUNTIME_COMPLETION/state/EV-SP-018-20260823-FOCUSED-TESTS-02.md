# EV-SP-018-20260823-FOCUSED-TESTS-02

| Field | Value |
|---|---|
| Evidence ID | `EV-SP-018-20260823-FOCUSED-TESTS-02` |
| Prompt / gap | SP-018 / OPEN-09 / R8 |
| Timestamp | 2026-08-23T16:47:04Z |
| Branch / commit | `main`; `HEAD == origin/main == e5835e983a9a98e3a1a5a955ef60a22a1fd6c932`; SP-018 edits are uncommitted and expected |
| Procedure | `./scripts/aura-test.sh /tmp/aura-sp018-final-context-formatted AuraContextTests`; `./scripts/aura-test.sh /tmp/aura-sp018-final-intent-formatted AuraIntentTests`; strict `swift-format lint` |
| Result | `AuraContextTests` **37/37** and `AuraIntentTests` **132/132** passed. Coverage includes active-workspace scope isolation, authority ranking, future/stale expiry, completed-task/backend omission, safe recent-file resolution, safe typed-slot propagation, dialogue provenance, and clarification before an unsafe mutation. |
| Artifact / hash | `Tests/AuraContextTests/ProductionReferenceCandidateAssemblerTests.swift` SHA-256 `d8ffa37576e037072fed33f5b1ebcf3ff63f7c80d282e59f8d94f5fff24c025d`; `Tests/AuraIntentTests/ProductionReferenceWiringTests.swift` SHA-256 `d05cbc777500247b40d008cb625982c059e5f185e30920df9929ea3ed6848ddd`; Context log SHA-256 `3058e164e764280aee95324d21630cbd5bb7f3d146f6a037e85e4aa5b5e30e1c`; Intent log SHA-256 `be7fbd53d08d1f05e1dbce87b79abbb19b34317799c5ffe66989cf99ed0c4c5d` |
| Evidence class | Deterministic integration evidence over the real `IntentEngine`/`ContextBuilder`/`ReferenceResolver` path; test providers are typed local seams, not external-service assertions. |
| Scope | Candidate scope, authority, freshness, omission, provenance, safe binding, and fail-closed ambiguity only. |
| Limitations | No user-present launched-app observation, real editor extension process, remote provider, raw audio, screenshot, secret, token, or private account data is included. |
