# AURA Maintainer Handoff — FINAL Audit (Blocked)

## Verdict

This is an operational handoff for a blocked development state, not a release
candidate or public-release handoff. FINAL cannot pass while R11 is incomplete
and R12 has no beta/RC evidence. Do not install, enroll participants, activate
telemetry, sign, notarize, publish, or deploy from this document.

## Supported development baseline

- macOS 27+ on Apple Silicon; primary profile: 16 GB unified memory.
- Current verified repository relation: `HEAD == origin/main ==
  e1004795e56df8c171422261eace96543649cf51`.
- The only release artifact evidence is explicitly
  `development_unverified`; it is not Developer ID, notarized, Gatekeeper, or
  clean-machine evidence.
- SwiftPM targets include `AURA`, `AuraPluginHost`, `AuraAutomationHelper`,
  and `AuraShellHelper`. The main process remains broader than the helper
  boundaries required for release.

## Safe local commands

```sh
python3 scripts/validate_runtime_completion.py --ci
python3 -m unittest discover -s scripts/tests
python3 scripts/validate_beta_readiness.py \
  --record AURA_RUNTIME_COMPLETION/state/beta-readiness.json
BUILD_ROOT=/tmp/aura-r11-release-artifact \
OUTPUT_DIR=/tmp/aura-r11-release-artifact/output \
./scripts/build-release-artifact.sh
```

The release validator is expected to fail closed on this host until full
Xcode/xcodebuild and separately authorized Apple release evidence are present.

## Operational boundaries

- Keep Push-to-Talk/text paths truthful; real wake-word, experimental neural
  voice, computer-use, mail-send, plugins, remote agents, signed updates, and
  launch-at-login remain excluded until their gates pass.
- Keep beta readiness blocked: no cohort, no consent collection, no telemetry
  transport, no raw audio/screenshots/prompts/model outputs/secrets/private
  identifiers, and no fabricated SLO or incident counts.
- For incidents, stop or disable the affected capability, preserve only
  redacted evidence, append the risk/incident record, and add a regression test
  before reconsidering scope.
- Revoke grants/tokens through the existing policy and Keychain lifecycle; do
  not place secrets in logs, ledgers, support bundles, or manifests.
- Recovery/update/migration/uninstall remain design and contract work. Do not
  infer an atomic rollback, safe mode, launch-at-login, factory reset, or clean
  uninstall from documentation alone.

## Required return path

Return first to R11 for full-Xcode, signing/notarization, clean-machine,
updater, recovery, migration, uninstall, and observed-CI evidence. Then return
to R12 for an authorized controlled beta, opt-in measurements, SLO/scenario
results, incident review, independent sign-offs, and a provenance-bound RC
package. FINAL may be closed only after those owning-track gates pass or are
explicitly scoped/accepted by authorized ownership.
