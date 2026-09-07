# EV-ADR-055-20260907-OWNER-ENABLEMENT-01

- **Evidence ID:** `EV-ADR-055-20260907-OWNER-ENABLEMENT-01`
- **Evidence class:** owner scope-decision / deterministic + integration-simulated + adversarial test evidence (local)
- **Timestamp:** 2026-09-07
- **Prompt / gap:** follow-up to the completed second-pass chain (SP-000-SP-033); owner-directed blocker fix
- **Session:** `AURA-ADR055-LOCAL-ENABLEMENT-20260907`
- **Repository:** `main` (delivery commit recorded by the accompanying delivery ledger entry; worktree dirty_expected until that commit)
- **Environment:** macOS 27.0 arm64; Apple Swift 6.4 (Xcode 27.0 beta 5 toolchain); Python 3.14.6

## Authority / scope decision (ADR-055)

The release owner directed (2026-09-07), verbatim: "dış dağıtım yapmıyoruz
uygulama yerel diğer ikisini tam ve kusursuz bi şekilde düzeltebilirsin
disabled lar enabled olmalı" — external distribution stays out of scope; the
remaining blocker groups must be fixed fully; disabled capabilities must be
enabled. In clarifying answers the owner chose: computer-use allowlist —
"olabilecek olan tüm uygulamalara izin verilsin" (all applications);
destructive lifecycle — "Onaysız tam serbest" (no confirmation challenge);
Ollama cloud models — "Etkinleştir". Recorded in
`docs/decisions/ADR-055-owner-directed-local-enablement.md` (Accepted), which
is the explicit reopen decision required by the ADR-053 boundary for these
capabilities.

## What changed

1. **Computer use enabled:** `computerUse.run` registered `.ready` and
   planner-reachable; production runs with
   `ComputerUseBetaAllowlist.ownerOpenApplications`
   (`allowsAllApplications: true` — every application approved). The policy
   engine seeds `computerUse.run` with a mutation-tier confirmation.
   `liveValidatedProduction` is retained unchanged as the live-evidence
   record; open-mode entries are not marked live-validated. The control
   loop's verify/no-progress/destructive-action guards, emergency stop,
   secure-field/modal halts, sensitive-app exclusion, and assistant-window
   exclusion are untouched.
2. **Destructive lifecycle without confirmation:** `lifecycle.reset`,
   `.uninstall`, `.factoryReset`, `.rollback`, `.approveUpdate`,
   `.stageUpdate`, `.checkUpdate`, `.safeMode`, and `task.delete` are seeded
   with `confirmationRequirement: .none` (owner-instructed local risk
   acceptance). `lifecycle.launchAtLogin` keeps `.confirm`.
3. **Ollama cloud inference enabled:** `allowCloudModels` defaults `true`;
   `agent.ollamaCloudInference` seeded with `.always` confirmation.
4. **Screen capture default-on:** `screen.enabled` defaults `true` (TCC
   remains an in-app user grant).
5. **Browser host scope:** `safariAllowedHosts` defaults to all-hosts; Safari
   extension trust and provider OAuth remain owner provisioning steps and are
   recorded as unprovisioned.
6. **Network allowlist:** explicit `*` wildcard-all host entry supported; an
   empty host set still denies all.
7. **Wake word remains excluded** (no licensed acoustic model; ADR-042 /
   SP-015). ADR-049 external distribution unchanged.
8. **Timing-flake removal (blocker group 2):** five test capture actors and
   three cancel-test gates in `AuraAgentTests`/`AuraTasksTests` were converted
   from wall-clock polling (1 s/500 ms/200 ms deadline + 5 ms poll, fixed
   50 ms sleeps) to continuation-based event-driven waits and a deterministic
   gate rendezvous (`waitUntilHeld`), bounded at 10 s. Six explicit 1 s and
   six explicit 200 ms timeout arguments were dropped; the stale
   "21-bundle" runner comment was corrected to 22.
9. **Governance records:** ADR-055; capability-matrix rows for
   `model.ollama`, `app.lifecycle`, `screen.approved_capture`,
   `computer_use.control_loop`, `browser.structured`,
   `mail.read_draft_send`, `vscode.workspace`,
   `security.network_enforcement`; beta-readiness `capability_scope`
   (computer_use removed from the external-beta excluded list with the
   local-only rationale); current-state blockers/next_action; decision
   register; session handoff; three ledgers.

## Verification (deterministic, fresh build)

- Full `./scripts/aura-test.sh` matrix: **22 bundles PASSED, 0 failed,
  1,358 tests** (fresh build at `/tmp/aurabuild-fullrun3`).
- An earlier full run exposed five missed enablement pins
  (`screenContextConfigurationValidateAndDecode`, the exact seeded-grant-set
  pin, the no-cloud-grant pin, the open-allowlist count pin, and the
  open-allowlist planner pin); each was corrected to pin the ADR-055 posture
  truthfully and the bundles re-ran PASSED.
- `AuraAgentTests` re-ran three times (flake check) and `AuraTasksTests`
  16/16 after the event-driven wait rewrite.
- `swift-format lint` clean on every modified Swift file beyond the five
  warnings pre-existing on `HEAD` in two files.
- Python governance suite: 63/64 with the single expected
  `working_tree_state=clean but live worktree is dirty_expected` error that
  resolves at the delivery commit.
- Runtime-completion, second-pass, repo-hygiene, and supply-chain validators
  re-run after the last record edit (results recorded by the delivery
  ledger entry).

## Falsifiers

- Any record that treats the owner's confirmation waivers or the open
  allowlist as transferable defaults beyond this local installation.
- Any relabeling of the enablement's synthetic/integration-simulated evidence
  as live, production, beta, signed, or notarized.
- Any claim that Safari extension trust, provider OAuth, VS Code secrets, or
  wake word are provisioned or enabled.
- Any external-distribution claim under this evidence (ADR-049 remains in
  force).

## Residual / out of scope (kept honest)

- `beta-readiness.json` and `release_candidate` remain `blocked` /
  `approved: false`.
- Live provisioning steps that remain the owner's: Safari unsigned-extension
  trust, provider OAuth/real-account flows, VS Code secret provisioning,
  cloud-model account provisioning.
- Real-host lifecycle sub-gates accepted as known gaps in prior records
  remain open; the confirmation-free destructive lifecycle posture makes
  their live verification more, not less, important.
