# ADR-055 — Owner-Directed Local Capability Enablement

- **Status:** Accepted
- **Date:** 2026-09-07
- **Owners:** AURA Runtime Completion Program / release owner (user)
- **Scope:** The local capability posture of the installed AURA app —
  computer use, the lifecycle capability set, Ollama cloud inference, screen
  context, browser host scope, and the related policy seed set and registry
  availability states
- **Amends:** ADR-053's live-evidence waiver boundary (enabling a previously
  `.disabled` capability on real accounts/apps reopens the affected gate —
  this ADR is that explicit reopen decision for the capabilities listed
  below); it does **not** change ADR-049 (local-only, no Developer ID /
  external distribution), ADR-051, or ADR-052.

## Context

The release owner directed (2026-09-07), verbatim:

- "dış dağıtım yapmıyoruz uygulama yerel" — the app stays local; external
  distribution remains out of scope under ADR-049.
- "diğer ikisini tam ve kusursuz bi şekilde düzeltebilirsin, disabled'lar
  enabled olmalı" — the remaining blocker groups must be fixed fully and
  flawlessly; disabled capabilities must become enabled.
- Computer-use allowlist: "olabilecek olan tüm uygulamalara izin verilsin" —
  permit **all** applications that can be permitted.
- Destructive lifecycle (reset / uninstall / factory-reset / rollback /
  update approval): "Onaysız tam serbest" — fully free, without a
  confirmation challenge.
- Ollama cloud models: "Etkinleştir" — enable.

The product was previously closed: `computerUse.run` was hard-disabled, the
destructive lifecycle capabilities stayed deny-by-default behind confirmation,
cloud inference was off, and screen capture shipped disabled. Leaving them
disabled was a default posture, not an owner decision. This ADR records the
owner's decision and its structural consequences.

## Decision

1. **Computer use is enabled with an open application allowlist.**
   `CapabilityRegistry` reports `computerUse.run` `.ready`; the planner is
   reachable. Production runs with
   `ComputerUseBetaAllowlist.ownerOpenApplications`
   (`allowsAllApplications: true`), under which **every** bundle identifier
   is approved. `liveValidatedProduction` is retained unchanged as the record
   of which applications carry real live evidence
   (`EV-SP-007-20260816-LIVE-02`); open-mode entries are **not** marked
   live-validated. The policy engine seeds `computerUse.run` with a
   mutation-tier confirmation on mutation actions. The controls that remain
   are structural, not per-app: the control loop's verification, no-progress,
   and destructive-action guards; emergency stop; secure-field and unexpected
   modal halts; the screen-context sensitive-app exclusion; and the exclusion
   of the assistant's own window.

2. **Destructive lifecycle and task deletion run without a confirmation
   challenge.** `lifecycle.reset`, `lifecycle.uninstall`,
   `lifecycle.factoryReset`, `lifecycle.rollback`,
   `lifecycle.approveUpdate`, `lifecycle.stageUpdate`,
   `lifecycle.checkUpdate`, `lifecycle.safeMode`, and `task.delete` are
   seeded with `confirmationRequirement: .none`. This is an
   **owner-instructed local risk acceptance** recorded here — it is a
   deliberate owner waiver for this local installation, **not** a transferable
   policy default, and any other deployment must not inherit it.
   `lifecycle.launchAtLogin` keeps its `.confirm` requirement (it is a
   persistent system-level change, not a destructive one).

3. **Ollama cloud inference is enabled.** `allowCloudModels` defaults to
   `true`, and `agent.ollamaCloudInference` is seeded with an `.always`
   confirmation requirement — the prompt is proxied to Ollama's hosted
   backend, so it carries the same on-every-request confirmation as the other
   third-party-bound capabilities (`agent.codexRun`, `agent.claudeRun`,
   `agent.copilotRun`).

4. **Screen context ships enabled.** `screen.enabled` defaults to `true`.
   The macOS Screen Recording TCC grant is still obtained in-app from the
   user; it is not and cannot be pre-granted by this decision.

5. **Browser structured reads default to an open host scope, with structural
   gates unchanged.** `safariAllowedHosts` defaults to an all-hosts
   (`*`-style) scope. The gates this does **not** lift remain real owner
   provisioning steps and are recorded as such: Safari's unsigned web
   extension requires the owner's explicit trust action, and provider
   OAuth/real-account flows require owner-provisioned credentials. No test or
   record may present those steps as already satisfied.

6. **Network enforcement semantics are unchanged.** An explicit `*`
   wildcard-all host entry is supported (owner-configured); an empty host set
   still denies all, and the enforcement engine's fail-closed behavior is
   untouched.

7. **What this ADR does not enable.** `voice.wake_word` remains excluded —
   there is no licensed acoustic model (ADR-042 / SP-015), and no owner
   instruction changes that. External distribution remains out of scope
   (ADR-049). Capabilities whose code-side enablement is complete but whose
   live conditions are not provisioned (Safari extension trust, provider
   OAuth, VS Code secrets) remain user-path-limited until the owner performs
   those steps.

8. **Evidence class.** The enablement is verified by deterministic unit,
   integration-simulated, and adversarial tests at their true evidence class.
   No synthetic evidence is relabeled as live, beta, signed, notarized, or
   production (extending ADR-053's falsifier rules to the newly enabled
   capabilities).

## Falsifiers

This decision is falsified by any record that (a) treats the owner's
confirmation waivers or open allowlist as a transferable default for any other
user, device, or deployment context, (b) relabels the newly enabled
capabilities' synthetic or integration-simulated evidence as live,
production, beta, signed, or notarized, (c) claims external distribution or
external release under this ADR (ADR-049 remains in force), or (d) marks
`voice.wake_word`, Safari extension trust, or provider OAuth as enabled
without their real (still-absent) preconditions.