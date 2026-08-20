# ADR-041 — Authenticated VS Code Extension Bridge and Coding-Workspace Contract

- Status: Accepted
- Date: 2026-08-20
- Owners: GitHub Copilot engineering session
- Supersedes: —
- Superseded by: —

## Context

R6 (`07_R6_VSCODE_AND_CODING_AGENTS.prompt.md`) requires a real authenticated
extension transport for the VS Code bridge while preserving policy enforcement,
replacing the earlier file-bridge contract. The first-pass R6 slice
(`EV-R6-20260808-POLICY-BRIDGE-01` and `EV-R6-20260808-TYPED-ROUTES-02`) proved
that `VSCodeAdapter` routes through `PolicyEngine` and that typed command/response
routes can carry workspace, editor, diagnostics, task, test, and terminal
information. What remained unproven was a real extension package, a user-controlled
shared-secret provisioning path, authenticated envelopes, and live failure-mode
behavior (disconnect, version mismatch, replay, stale editor, dirty buffer,
confirmation-required paths). SP-012 closes the deterministic/source-side
portion of that gap and records the live-extension blocker honestly.

The codebase already provides the primitives this track composes over:

- **`CapabilityRegistry`/`CapabilityManifest`** (ADR-038) — the sole production
  source of capability contracts. `InitialCapabilitySet` already registers the
  VS Code capabilities as `.disabled` with a truthful reason until the bridge
  is live.
- **`PolicyEngine`** (ADR-006/ADR-037) — deny-by-default capability/grant/
  confirmation engine. `VSCodeAdapter` already awaits a policy decision before
  CLI, shell, or bridge execution.
- **`SecretStoring`/`KeychainSecretStore`** (ADR-020) — real macOS Keychain
  generic-password storage, never iCloud-synced, with a protocol seam so tests
  never touch the real Keychain. This track uses a symmetric HMAC secret stored
  by AURA in the Keychain, in contrast to Safari's asymmetric P-256 pin.
- **`ContentProvenance`/`PromptInjectionClassifier`** (ADR-020) — untrusted
  external content is typed as non-authoritative and scanned before it can
  influence capability selection, policy, confirmation, or action. VS Code
  state snapshots (editor text, diagnostics, terminal output) are treated as
  untrusted content.
- **`ConfirmationTransaction`** (ADR-037) — immutable, hash-bound, nonce/expiry-
  bounded confirmation that does not survive restart. Write-capable coding-agent
  actions must pass this gate.

The capability matrix records VS Code capabilities as `.disabled` until live
bridge health is proven. `RISK-BRIDGE-INCOMPLETE` and
`RISK-VSCODE-POLICY-NOT-ENFORCED` are the two risks this ADR directly mitigates.

## Decision

1. **The VS Code bridge uses a user-controlled symmetric HMAC secret.** AURA
   stores the secret in the macOS Keychain via `SecretStoring`; the companion
   VS Code extension stores the same secret in VS Code's own encrypted
   `SecretStorage`. The secret is never transmitted between the processes over
   any network, never appears in logs/events/prompts/speech, and is never
   included in the file envelopes themselves. The user provisions the bridge by
   entering or confirming the secret in the extension once AURA has generated or
   revealed it. Either side can revoke the secret, which immediately degrades all
   VS Code capabilities back to `.disabled`. This mirrors the Safari bridge's
   asymmetric P-256 pin but uses symmetric HMAC because both halves run under the
   user's local trust boundary and VS Code exposes a first-class encrypted
   `SecretStorage` API.

2. **Every envelope is signed and freshness-bound.** Both command and response
   envelopes bind `protocolVersion`, `extensionID`, `nonce`, `issuedAt`,
   `expiresAt`, workspace path, actor, and payload. The HMAC tag covers the full
   canonical envelope. The Swift side rejects expired envelopes, mismatched
   protocol versions, unknown extension IDs, and reused nonces. This closes
   replay, stale-state, downgrade, and impersonation paths on the file transport.

3. **VS Code capabilities remain `.disabled` until live bridge health is proven.**
   `CapabilityRegistry` registers `vscode.runTask`, `vscode.runTest`,
   `vscode.openFile`, `vscode.revealFile`, `vscode.readEditor`, and related
   capabilities with `vscodeDisabledReason` that explicitly states they start
   disabled until the authenticated extension bridge is live. Health is derived
   from `VSCodeBridgeHealth` (`.ready`, `.unauthorized`, `.disconnected(reason:)`,
   `.versionMismatched`, `.stale`) and refreshed on every external-availability
   probe and on every text submission. The bridge is never trusted on source
   construction alone; it must observe a recent, valid, authenticated snapshot
   from the extension.

4. **Policy enforcement stays central and is never bypassed for convenience.**
   `VSCodeAdapter.executeViaBridge` authorizes the action through `PolicyEngine`
   before issuing any bridge command. A missing, denied, or confirmation-required
   decision fails closed. Dirty-buffer or write-capable actions require a
   `ConfirmationTransaction`. The extension does not execute actions autonomously;
   it only collects state and responds to authenticated commands issued by AURA.

5. **Disconnect and degraded states are first-class, truthful, and actionable.**
   The bridge health surface distinguishes: not provisioned, secret revoked,
   extension not installed, version mismatch, stale snapshot, disconnected, and
   ready. Each maps to a distinct `CapabilityAvailability` reason so the UI and
   dialogue present the honest state rather than a generic failure.

6. **The extension package is a separable, buildable, installable artifact.**
   `AuraVSCodeExtension/` is a standard VS Code extension with `package.json`,
   `tsconfig.json`, TypeScript sources, and a `vsce package` target. It declares
   three commands (provision secret, revoke secret, show health) and settings
   for the three file paths and snapshot interval. It is built and packaged
   independently of AURA. The Swift composition root constructs the bridge only
   when a non-empty extension ID and a retrievable Keychain secret are present;
   otherwise it leaves the bridge `.unauthorized`.

## Alternatives considered

- **Asymmetric P-256 pin like Safari.** Rejected for the VS Code path because
  both halves run under the user's local trust boundary and VS Code provides a
  first-class encrypted `SecretStorage`; symmetric HMAC is simpler, equally
  secure for this local threat model, and avoids the Safari-specific sandboxed/
  unsandboxed keychain split. The asymmetric option remains available if the
  trust model changes.
- **Shared secret stored in a plain file or configuration.** Rejected — ADR-020
  and `ConfigurationKeyDefinition.sensitive` already mandate Keychain-only for
  sensitive values; a plain file would violate the established secret boundary.
- **No authentication on the local file transport.** Rejected — the prompt
  explicitly requires an authenticated extension transport; an unsigned local
  file bridge would allow any process with access to the command/response files
  to impersonate AURA or the extension.
- **Extension executes actions without AURA policy review.** Rejected — models
  propose typed intents; the policy engine authorizes; adapters execute. The
  extension is an adapter, not an autonomous agent.
- **Enable VS Code capabilities as soon as the extension source exists.**
  Rejected — the prompt explicitly requires capabilities to stay disabled until
  live bridge health is proven, matching the `ComputerUseBetaAllowlist` /
  `.liveValidated` pattern from ADR-039.

## Security and privacy impact

- The symmetric secret is Keychain-only on the AURA side and `SecretStorage`-only
  on the extension side; the value never appears in events, logs, prompts,
  speech, or the file envelopes.
- Every command/response/state envelope is HMAC-tagged with protocol version,
  extension identity, nonce, freshness, and payload binding, preventing replay,
  tampering, downgrade, and impersonation on the file transport.
- VS Code capabilities start disabled and remain disabled until a live,
  authenticated, fresh bridge snapshot is observed.
- Write-capable coding actions remain gated by `PolicyEngine` and immutable
  `ConfirmationTransaction`; the extension never executes without AURA
  authorization.
- Editor text, terminal output, and diagnostics are treated as untrusted
  external content with non-authoritative provenance.

## Operational impact

- `Sources/AuraVSCode/VSCodeBridgeSecretStore.swift` adds a Keychain-backed
  symmetric secret store with per-extension-ID namespacing.
- `Sources/AURA/AuraKernel_Construction.swift` gains a
  `constructVSCodeAdapter(configuration:shell:policyEngine:)` helper that builds
  the bridge only when provisioned.
- `Sources/AURA/AuraKernel_VSCodeAvailability.swift` derives VS Code capability
  availability from live bridge health and refreshes it on external probes and
  text submission.
- `AuraVSCodeExtension/` is the companion VS Code extension package.
- `Sources/AuraCore/Configuration_VSCodeConfiguration.swift` is extended with
  extension ID, secret service name, and bridge file paths.
- `Tests/AuraVSCodeTests/AuraVSCodeTests_More.swift` covers disconnect, version
  mismatch, replay, stale editor, dirty buffer, and confirmation-required paths.

## Migration

No breaking migration. Existing VS Code capabilities remain `.disabled` until
provisioning occurs. `AuraConfiguration` JSON files decode unchanged; missing
VS Code bridge keys merge in empty defaults, leaving the bridge `.unauthorized`.

## Validation evidence

- Deterministic Swift unit/integration tests for: authenticated envelope
  construction; secret provisioning, retrieval, and revocation; version mismatch
  rejection; replay nonce rejection; freshness expiry rejection; extension ID
  mismatch; stale snapshot handling; dirty-buffer confirmation denial; missing
  policy engine fail-closed; disconnect/degraded health propagation; and
  capability availability remaining disabled until `.ready`.
- Full Swift repository regression passes with no failing targets.
- Second-pass program validator passes.
- The companion extension package compiles with `tsc` and declares `vsce
  package` as its packaging target. Live installation, provisioning, and
  authenticated round-trip acceptance remain required before SP-012 can be marked
  `completed`.

## Consequences

- **Positive:** R6 gains a real authenticated extension bridge architecture with
  user-controlled provisioning, revocable Keychain-backed secrets, signed/fresh
  envelopes, policy-gated execution, and truthful disabled-until-live capability
  states.
- **Negative:** Live acceptance requires installing the extension in VS Code,
  entering the shared secret, and exercising real command/response/state round
  trips including failure modes. This has not been performed in the current
  session.
- **Risk:** `RISK-BRIDGE-INCOMPLETE` is materially mitigated by this ADR's
  decisions but not closed — the live extension path is still unproven.
  `RISK-VSCODE-POLICY-NOT-ENFORCED` is mitigated by deterministic tests but
  remains open for live confirmation/UI behavior.

## Related

- `AURA_RUNTIME_COMPLETION/prompts/second_pass/SP-012_AUTHENTICATED_VS_CODE_EXTENSION_BRIDGE.prompt.md`
- `docs/decisions/ADR-038-capability-registry-and-planner.md`
- `docs/decisions/ADR-020-security-hardening.md`
- `docs/decisions/ADR-037-runtime-health-and-confirmation-transactions.md`
- `docs/decisions/ADR-039-production-computer-use-planner.md`
