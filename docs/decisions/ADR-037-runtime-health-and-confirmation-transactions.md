# ADR-037 - Runtime Health and Confirmation Transactions

- Status: Accepted
- Date: 2026-08-02
- Owners: GitHub Copilot
- Supersedes: -
- Superseded by: -

## Context

The composition root constructed many subsystems but exposed little information about whether each one was ready, disabled, permission-blocked, or degraded. Confirmation was also represented partly by policy challenges and partly by implicit router behavior, which made replay, plan changes, and post-execution truth difficult to audit.

## Decision

1. `RuntimeHealthRegistry` is the typed source of truth for constructed subsystem state. It records bounded component ID, status, detail, and observation time. Supported states include ready, degraded, disabled by configuration, permission blocked, dependency missing, configuration invalid, loading, circuit open, unsupported, and failed.
2. The registry publishes `RuntimeHealthChangedEvent` on every update when an event bus is supplied. The UI consumes the snapshot at bootstrap and live change events afterward. A subsystem cannot be shown ready merely because its initializer returned an object; explicit dependency and permission state is recorded.
3. A side-effecting confirmation is one `ConfirmationTransaction` identified by request ID, plan hash, capability, target, side effects, nonce, expiry, turn context, response, and lifecycle state. The transaction is proposed, authorized once, executing, executed, verifying, and then verified or failed; cancellation and unknown outcomes remain terminal fail-closed states.
4. `PolicyEngine` owns challenge validation and transaction authorization. The response nonce, request ID, and expected plan hash must match. `ToolRouter` cannot bypass mandatory confirmation, and a changed plan or context cannot inherit an earlier approval.
5. Restart behavior is fail-closed for R1: a new process has no authorized in-memory transactions, so no prior approval can be replayed. Durable checkpoint/resume is deliberately deferred until its storage and recovery contract is specified; pending work is cancelled rather than silently resumed.
6. Execution and verification are separate calls. A tool may report execution success while verification fails; that outcome is never promoted to a successful completed confirmation transaction.

## Alternatives considered

- Treat every constructed service as ready. Rejected because unavailable dependencies and ungranted permissions become false-success UI.
- Store a boolean `confirmed` beside a policy request. Rejected because it cannot bind approval to an immutable plan, nonce, expiry, context, and one-time execution.
- Resume pending approvals automatically after restart. Rejected because the user-visible state and target may have changed; R1 fails closed until a future explicit recapture flow exists.
- Mark execution complete from process exit alone. Rejected because execution evidence is not an independent capability-specific postcondition.

## Security and privacy impact

Transaction records contain bounded target summaries and plan hashes, not raw secrets or ambient content. Missing UI, dismissal, timeout, overlap, replay, plan change, context mismatch, restart, and verification failure deny or fail closed.

## Operational impact

`AuraKernel` records health as it constructs and starts services. `AuraAppModel` renders degraded and unsupported states and updates them through the live event bus. Policy and tool adapters must call the transaction lifecycle around side effects when a confirmation exists.

## Validation evidence

- `AuraCoreTests` covers health snapshots, live health events, confirmation expiry, plan change, replay, context mismatch, one-time execution, verification, and restart fail-closed behavior.
- `AuraPolicyTests` covers confirmation allow/deny, tampering, expiry, grants, and transaction integration.
- `AURAIntegrationTests` covers safe fallback denial, interactive presenter denial, and truthful STT failure propagation.
- The complete R1 evidence index entry will record the fresh full-suite result and explicitly retain the no-durable-resume limitation.

## Limitations

R1 provides adapter-level verification contracts and a distinct verifying state, but no universal verifier can be invented for capabilities that lack a concrete postcondition adapter. Durable transaction checkpoints and a resume/recapture UX remain future work; restart is intentionally fail-closed.

## Consequences

- Positive: runtime availability and confirmation state are inspectable rather than inferred.
- Positive: approval replay and false completion have explicit guards and tests.
- Negative: unavailable optional services remain visible as degraded instead of silently disappearing, and restart may require the user to issue a fresh request.
