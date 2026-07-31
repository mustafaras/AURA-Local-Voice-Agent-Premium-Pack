# AURA Runtime Completion Decision Register

Use this file as a compact index. Full rationale belongs in ADR files. Status values: `Proposed`, `Accepted`, `Superseded`, `Rejected`, `Deferred`.

| ID | Decision | Owning track | Status | Required before | ADR path | Notes |
|---|---|---:|---|---|---|---|
| ADR-034 | Runtime completion program, `TurnContext`, capability registry, and orchestration ownership | R1 | Proposed | R1 implementation | `docs/decisions/ADR-034-runtime-completion-capability-registry.md` | Establish one production integration spine and explicit runtime health. |
| ADR-035 | Correlation, causation, verification, and truthful completion semantics | R1 | Proposed | R1 completion | `docs/decisions/ADR-035-turn-context-truthful-completion.md` | Execution success is not verification success. |
| ADR-036 | Hybrid Turkish/English deterministic NLU, local structured NLU, and dialogue routing | R2 | Proposed | R2 implementation | `docs/decisions/ADR-036-bilingual-nlu-dialogue-routing.md` | Define local/remote model modes, schemas, confidence, and degraded behavior. |
| ADR-037 | Immutable confirmation transaction and resumable execution | R1 | Proposed | Side-effecting capability expansion | `docs/decisions/ADR-037-confirmation-transaction-resume.md` | Bind approval to plan hash, target, nonce, risk, and expiry. |
| ADR-038 | Typed capability manifest and multi-step plan contract | R3 | Proposed | R3 implementation | `docs/decisions/ADR-038-capability-manifest-planner.md` | Replace unbounded enum/switch growth with closed registered schemas. |
| ADR-039 | Production computer-use planner and approved application beta boundary | R4 | Proposed | Live computer-use enablement | `docs/decisions/ADR-039-production-computer-use-planner.md` | Accessibility-first, fresh observation, strict typed actions, no raw model execution. |
| ADR-040 | Browser/mail/calendar/contacts integrations, OAuth scopes, and trust boundaries | R5 | Proposed | R5 implementation | `docs/decisions/ADR-040-productivity-integrations-oauth.md` | Read-first rollout and explicit send/mutation confirmation. |
| ADR-041 | Authenticated VS Code extension bridge and coding-workspace contract | R6 | Proposed | R6 implementation | `docs/decisions/ADR-041-vscode-extension-bridge.md` | Enumerated commands, authenticated local IPC, dirty-buffer safety. |
| ADR-042 | Real wake-word engine, STT router, TTS chain, and local model resource governor | R7 | Proposed | Wake-word/model enablement | `docs/decisions/ADR-042-voice-routing-resource-governor.md` | Must fit 16 GB hardware and preserve Push-to-Talk fallback. |
| ADR-043 | User memory, preference scope, context budget, and explainability UI | R8 | Proposed | R8 implementation | `docs/decisions/ADR-043-memory-personalization-controls.md` | Explicit persistence, provenance, correction, export, and deletion. |
| ADR-044 | Privileged XPC/helper topology, network enforcement, and secret boundaries | R10 | Proposed | External beta | `docs/decisions/ADR-044-privileged-helper-topology.md` | Separate local control powers from model/network process. |
| ADR-045 | Stable toolchain, deployment target, build/archive, Developer ID, and notarization | R0/R11 | Proposed | External beta | `docs/decisions/ADR-045-toolchain-release-pipeline.md` | Distinguish development SDK from minimum release target. |
| ADR-046 | Signed update, rollback, downgrade protection, safe mode, and recovery | R11 | Proposed | Release candidate | `docs/decisions/ADR-046-signed-update-recovery.md` | Prefer mature auditable mechanism over custom cryptography. |
| ADR-047 | Beta evidence, SLOs, release-candidate authority, and final completion declaration | R12 | Proposed | Final acceptance | `docs/decisions/ADR-047-beta-slos-release-authority.md` | Define objective release-candidate evidence and false-success threshold. |

## Decision rules

- Add a row before implementing a material decision.
- Do not mark `Accepted` until the ADR contains context, decision, alternatives, consequences, migration, security/privacy analysis, and verification plan.
- Record supersession rather than rewriting history.
- Update `current-state.json` when an accepted decision changes dependencies, gates, or program order.
