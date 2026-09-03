# AURA Maintainer Handoff — FINAL Audit (Blocked)

## Verdict

This is an operational handoff for a blocked development state, not a release
candidate or public-release handoff. FINAL cannot pass while R11 is incomplete
and R12 has no beta/RC evidence. Do not install, enroll participants, activate
telemetry, sign, notarize, publish, or deploy from this document.

`EV-SP-032-20260902-FINAL-RECONCILIATION-01` is the current edit-only FINAL
cleanup evidence. It records no clean-Mac, end-to-end, beta, lifecycle, or
release procedure; SP-032 remains blocked.

## Supported development baseline

- macOS 27+ on Apple Silicon; primary profile: 16 GB unified memory.
- Current verified repository relation: `HEAD == origin/main ==
  bee334782262089fa117124ababa9b3c6dfed394`.
- The exact SP-031 package is approved only for local
  `development_unverified` use (`EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`).
  It is not a beta, release candidate, production, or external-release artifact.
- SwiftPM targets include `AURA`, `AuraPluginHost`, `AuraAutomationHelper`,
  and `AuraShellHelper`. The main process remains broader than the helper
  boundaries required for release.

## Safe local commands

```sh
python3 scripts/validate_runtime_completion.py --ci
python3 scripts/validate_second_pass_program.py
python3 scripts/validate_beta_readiness.py \
  --record AURA_RUNTIME_COMPLETION/state/beta-readiness.json
python3 scripts/validate_release_manifest.py \
  --manifest /tmp/aura-sp031-local-rc-20260902/output/AURA-development-unverified.manifest.json \
  --bundle-root /tmp/aura-sp031-local-rc-20260902/app-build/AURA.app \
  --artifact /tmp/aura-sp031-local-rc-20260902/output/AURA-development-unverified.zip
```

These commands only reconcile existing records and the already-bound local
package. They do not launch or install AURA, create a release, or establish
clean-Mac, beta, lifecycle, or release acceptance. Full build/test workflows
need separately scoped authority because their harnesses create scratch Git
worktrees and can probe installed agent CLIs.

## Operational boundaries

- Keep Push-to-Talk/text paths truthful; real wake-word, experimental neural
  voice, computer-use, mail-send, plugins, remote agents, signed updates, and
  launch-at-login remain excluded until their gates pass.
- Keep beta readiness blocked: one local participant is enrolled/consented and
  all five scoped sign-offs are recorded, but there is no qualifying live-beta
  SLO set, live scenario window, or incident review. Telemetry remains disabled
  with `transport: none`; never record raw audio, screenshots, prompts, model
  outputs, secrets, or private identifiers.
- For incidents, stop or disable the affected capability, preserve only
  redacted evidence, append the risk/incident record, and add a regression test
  before reconsidering scope.
- Revoke grants/tokens through the existing policy and Keychain lifecycle; do
  not place secrets in logs, ledgers, support bundles, or manifests.
- Recovery/update/migration/uninstall remain design and contract work. Do not
  infer an atomic rollback, safe mode, launch-at-login, factory reset, or clean
  uninstall from documentation alone.

## Required return path

Return first to the owning R2-R10 direct capability, privacy, accessibility, and
privilege gates. Then return to R11 for direct local lifecycle acceptance:
sleep/wake/crash recovery, safe-mode export, populated-profile migration,
update/rollback, uninstall/factory reset, support-bundle privacy, and the
applicable clean-profile evidence. ADR-049 permanently excludes Developer ID,
notarization, and external clean-machine distribution; do not present those as
remaining local-product requirements. Return to R12 for qualifying live SLOs,
live scenarios, incident review, and an approved release-candidate decision.
FINAL may close only after its owning gates genuinely pass or are explicitly
scoped/accepted by authorized ownership.
