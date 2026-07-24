# ADR-006 — Policy Engine Architecture

| Field | Value |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-07-25 |
| **Author** | GitHub Copilot |
| **Supersedes** | — |

## Context

Phase 5 of the AURA implementation roadmap requires a deny-by-default policy engine that authorizes every model-proposed action before an adapter executes it. The engine must support risk tiers, capabilities, scoped and time-bounded grants, deny rules, confirmation binding with tamper-evident challenges, expiry, and structured audit events. It must be testable without live models or user interface, must persist grants and deny rules across restarts, and must respect the project's safety/privacy ordering (Safety → Correctness → Recoverability → Latency → Convenience).

## Decision

1. **New `AuraPolicy` target.** The policy engine lives in a dedicated `AuraPolicy` library target that depends on `AuraCore` and `AuraStore`. Shared vocabulary (`Capability`, `Grant`, `PolicyDecision`, etc.) remains in `AuraCore` because many targets already depend on it and `AuraCore` has no dependencies.

2. **Actor-isolated `PolicyEngine`.** `PolicyEngine` is a Swift `actor` that owns the canonical in-memory grant and deny-rule sets. All mutating operations (issue/revoke grants, upsert/remove deny rules, confirm challenges) run through actor-isolated methods, eliminating data races on policy state.

3. **Deny-before-grant evaluation order.** Every `PolicyEvaluationRequest` is checked against deny rules first. A matching deny rule produces an immediate `deny` decision with a stable reason string and no grant is considered.

4. **Scoped grant matching.** A grant applies only when:
   - its capability domain and action match the request exactly;
   - the request target matches every constrained `ResourcePattern` in the grant (`any`, `appID`, `filePath` glob, `directory`, `command` regex, `argument` subset, `environment` key subset, `network` host/port);
   - the grant has not expired (`createdAt <= now < expiresAt` if expiry is present).

5. **Default behavior per risk tier.** If no grant matches, the request falls back to the `PolicyConfiguration` default matrix: `denyByDefaultTiers` deny, `allowByDefaultTiers` allow. The default deny set includes all tiers except `observation`. Any overlap between `allowByDefaultTiers` and `denyByDefaultTiers` is a configuration error caught by `validate()`.

6. **Confirmation binding.** A matching grant or the default tier may require explicit confirmation. `ConfirmationRequirement` supports `none`, `oncePerSession`, `always`, `forRiskTier(PermissionRiskTier)`, and `when(pattern: ResourcePattern)`. When confirmation is required, the engine issues a `PolicyConfirmationChallenge` containing a random nonce, expiration, and a SHA-256 expected hash over a canonical action summary. The engine records the pending challenge; a later `PolicyConfirmationResponse` is accepted only if the hashes match, the challenge has not expired, and the response is for the same request.

7. **Tamper-evident challenge hashes.** Challenge hashes are computed with `CryptoKit.SHA256` over a deterministic string that joins the request ID, nonce, capability identifier, target summary, and expiry. This prevents a leaked confirmation response from being replayed for a different action or time window without access to the nonce.

8. **Audit events via the typed event bus.** Every evaluation, confirmation issue, confirmation response, grant mutation, and deny-rule mutation emits a typed event to `AuraEventBus`. Audit payloads live in `AuraCore` (`PolicyEventPayloads.swift`) so subscribers in any target can observe policy decisions without importing `AuraPolicy`.

9. **Persistence through `AuraStore`.** Grants and deny rules are serialized to JSON and stored under configurable keys in the SQLite-backed `AuraStore`. On initialization the engine loads existing grants and deny rules from the store. The store layer has no policy semantics; it only persists the JSON blobs.

10. **Configuration embedded in `AuraConfiguration`.** `PolicyConfiguration` is added to `AuraConfiguration`, decoded with `decodeIfPresent`, merged with defaults, and validated alongside other subsystems. Default confirmation tier is `.mutation`, confirmation expiry is 60 seconds, and deny-by-default covers `.reversible`, `.mutation`, and `.destructive`.

11. **Privacy-safe logging.** Policy audit events include capability identifier, target summary, decision outcome, and correlation/causation IDs. They never include raw environment values, file contents, screenshots, audio, secrets, or full command arguments.

## Consequences

- **Positive:** The policy engine is strictly isolated, deny-by-default, testable without UI or models, and emits typed events for every authorization decision. Confirmation binding and expiry make high-risk actions explicit and time-bounded.
- **Negative:** The engine does not yet integrate with a real intent engine or tool adapters; it evaluates `PolicyEvaluationRequest` values produced by callers. The `oncePerSession` confirmation scope uses an in-memory set that is reset on process restart.
- **Risk:** Pattern matching (globs, regexes) is implemented with Foundation helpers and is not suitable for untrusted rule sources; deny rules and grants are expected to originate from user action or trusted configuration. Complex regex rules could impact latency for high-frequency actions.

## Related

- `prompts/implementation/05_05_POLICY_ENGINE.prompt.md`
- `docs/security/25_PERMISSION_SYSTEM.md`
- `docs/security/26_SECURITY_MODEL.md`
- `docs/security/27_PRIVACY_MODEL.md`
- `Sources/AuraCore/PolicyTypes.swift`
- `Sources/AuraCore/PolicyEventPayloads.swift`
- `Sources/AuraPolicy/PolicyEngine.swift`
- `Tests/AuraPolicyTests/PolicyEngineTests.swift`
- `Package.swift`
