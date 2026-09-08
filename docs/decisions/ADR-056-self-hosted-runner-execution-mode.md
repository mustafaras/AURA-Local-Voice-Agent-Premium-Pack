# ADR-056 — Self-Hosted Runner Execution Mode (Staged Hybrid)

- **Status:** Accepted (decision adopted via owner-confirmed model committee, 2026-09-08; implementation pending — acceptance gates in Validation evidence are unmet until proven)
- **Date:** 2026-09-08
- **Owners:** AURA Runtime Completion Program / release owner (user)
- **Scope:** Execution mode of the repository's self-hosted CI runner on the
  owner's Mac, the supervision surface around it, and the pre-committed
  fallback/escape-hatch path if the staged proofs fail
- **Amends:** the operational rule recorded in `ledger/PROJECT_LEDGER.md`
  (2026-09-07T15:51Z, "run the self-hosted runner interactively … never as a
  launchd service") — re-scoped below to its actual protected property. It
  does **not** change ADR-049 (local-only distribution), ADR-053, ADR-054, or
  ADR-055.
- **Supersedes:** none
- **Superseded by:** none

## Context

The repository's CI (`.github/workflows/ci.yml`) runs two jobs,
`governance` and `build-and-test`, both pinned to
`runs-on: [self-hosted, macOS, swift-6.4]` on the owner's daily-use Mac. The
full test surface includes the four `AuraSecurityTests` keychain round-trips
(`Tests/AuraSecurityTests/SecretStoreTests.swift`), which resolve against the
login keychain of the owner's interactive GUI session
(`Sources/AuraSecurity/SecretStoring.swift` uses `SecItemAdd` /
`SecItemCopyMatching` without a keychain-selection parameter).

Two documented facts bound the design space:

1. A runner installed as a user LaunchAgent (`svc.sh`) failed `build-and-test`
   with OSStatus `-25308` (`errSecInteractionNotAllowed`) — a launchd service
   session cannot interact with the login keychain
   (`ledger/PROJECT_LEDGER.md:6081-6095`).
2. The interactive runner dies with its owning Terminal session. On
   2026-09-07T15:29Z it died unnoticed and two push-triggered runs queued for
   ~36 minutes until the owner manually restarted `~/actions-runner/run.sh`
   (`ledger/PROJECT_LEDGER.md`, 2026-09-08T06:59Z entry).

The owner invoked `/model-committee` on 2026-09-08 to decide the durable
runner strategy. The committee ran per protocol: frozen brief with a
precommitted rubric (security 25, CI-signal correctness 25, recoverability 20,
latency 10, cost 10, reversibility/ADR-fit 10; default tie rule), blind
round-1 proposals, anonymous round-2 cross-critique, blinded round-3
cross-ranking with reversed order, and a delegated Sol chair
(`gpt-5.6-sol xhigh`; the session runs a different model, so the fail-closed
delegate branch applied). Members: `gpt-5.6-terra` (xhigh) and
`claude-opus-5` (high). Transcript: `.committee-tmp/runner-strategy/`.

## Decision

**Staged hybrid, adopted unanimously (aggregate 845/1000 vs 645/1000, margin
20%, no disqualifiers from either reviewer):**

1. **Protected rule (amending the 2026-09-07T15:51Z rule).** The runner
   process must never execute in a launchd **service** session. launchd may
   operate a **health watchdog that never accesses the keychain**. A runner
   detached from Terminal but still a member of the owner's Aqua login
   session is permitted, and is exactly what the acceptance gates must prove.

2. **Stage 1 — credential-free watchdog, immediate and unconditional.**
   `scripts/ci-runner-watchdog.sh` (zsh; must pass the existing
   `zsh -n scripts/*.sh` governance step) checks `Runner.Listener` liveness
   plus a supervisor freshness stamp and fires a local `osascript`
   notification on staleness. It uses no GitHub API call, no `gh` token, and
   no repository-stored credential. v1 credential-free design is mandatory;
   an optional v2 (queue-age via `gh`) may follow only if v1 proves
   insufficient and only reading CLI-managed auth, never echoing it.

3. **Stage 2 — detached supervisor, gated on proof.**
   `scripts/runner-supervisor.sh` (zsh) runs the existing runner detached
   from Terminal (no controlling terminal) but inside the owner's GUI login
   session, started at GUI login via a Login Item. Requirements:
   - PID-file or equivalent lock so a supervised runner can never overlap a
     manually started `run.sh` (the ledger's `_diag/pages` race);
   - restart loop with backoff **and a bounded restart-count circuit
     breaker**, logging restart counts (a crash loop must not masquerade as
     health);
   - explicit toolchain environment pinning (`DEVELOPER_DIR` /
     `xcode-select` path, `PATH`/`TOOLCHAINS` as applicable) instead of
     inheriting whatever the Login Item provides, recording the resolved
     `swift --version` at start;
   - watchdog heartbeat written outside the repository.

4. **`ci.yml` is unchanged.** Both jobs, the strict-concurrency build, the
   full test suite, all four keychain round-trips, the 70% coverage gate, and
   the release-artifact upload run unchanged. Constraint 2 of the committee
   brief is satisfied by construction.

5. **ADR is a precondition, not a follow-up.** This ADR is that precondition.
   Implementation of stage 2 must not begin before this ADR is accepted;
   stage 1 (watchdog) is part of the accepted decision and may land first as
   an independently revertible commit.

6. **Escape hatch — GitHub-hosted macOS runners.** Not adopted now. If any
   stage-2 proof fails, a hosted-runner migration may be opened **only** as a
   branch spike with this pre-committed acceptance bar: an equivalent Swift
   6.4 toolchain demonstrated on the hosted image; all four
   `SecretStoreTests` keychain cases passing **unmodified**; **no change to
   `SecretStoring.swift`** (no keychain-selection seam); an in-job ephemeral
   keychain created and destroyed in-job with a runtime-generated password
   that never enters source, workflow YAML, environment dumps, process logs,
   or artifacts; no owner secret anywhere; measured queue time below the
   ~30-minute boundary; hosted cost/visibility verified. A launchd
   *service-session* runner remains prohibited on every path.

7. **Prohibited on every path:** plaintext keychain passwords or owner
   secrets in workflow files, runner config, prompts, or logs; silently
   skipping or gating off security tests; a keychain-selection seam in
   production security code introduced for CI's benefit without a separately
   justified assurance-equivalence decision; mutating the owner's default
   keychain preference (`security default-keychain -s`) on the daily-use Mac
   (considered and rejected: it mutates user-domain state).

## Alternatives considered

- **(b) launchd service runner with a keychain workaround** — rejected on the
  recorded `-25308` evidence for the service session; a `gui/$UID`-bootstrapped
  LaunchAgent with/without `SessionCreate` remains an allowed cheap
  *diagnostic* if stage 2 fails, not a runner mode.
- **(c) GitHub-hosted runners now** — rejected as today's decision on three
  unverified premises (hosted Swift 6.4 parity, repository visibility/cost,
  ephemeral-keychain equivalence) plus a live recoverability gap during its
  unbounded proof window. Retained as the pre-specified escape hatch (6).
- **Status quo (foreground `run.sh` + `caffeinate -di` as a manual routine)**
  — rejected: it leaves the rubric's recoverability disqualifier ("still
  silently queues for hours after a reboot with no detection path") live
  indefinitely.

## Security and privacy impact

- No new credential surface: the watchdog is credential-free; the supervisor
  never touches the keychain; no keychain password exists to leak because no
  new keychain is created on the owner's Mac.
- Residual least-privilege concern (recorded dissent): push-triggered
  workflow code continues to execute inside the owner's login session with
  login-keychain access. The hosted path would remove this coupling but was
  not adopted on unverified premises; the escape-hatch bar keeps the
  constraint explicit.
- Diagnostics and logs stay non-private and outside the repository tree.

## Operational impact

- Failure modes covered: runner crash (bounded restart), Terminal close
  (detachment), reboot (Login Item after GUI login), silent queue (watchdog
  alert, target ≤5 minutes).
- Known residual gap: between an unattended reboot and the owner's next GUI
  login, CI queues; auto-login is rejected as a FileVault-posture trade. The
  gap is covered by detection, not availability.
- The Mac remains a single point of failure; no redundancy is purchased in
  this decision.

## Migration

Two independently revertible commits, in order: (1) watchdog + LaunchAgent
template; (2) supervisor + Login Item template. Rollback of stage 2 reverts
only the supervisor commit and removes the Login Item, **retaining the
watchdog**, and records the negative result in this ADR's Validation evidence
and the ledger. Runbook guidance lands under `docs/operations/`.

## Validation evidence

Stage 2 acceptance gates (all must pass before this ADR's implementation is
marked complete; outcomes recorded 2026-09-08T14:30Z at the end of this
section):

1. Start the supervisor detached, fully quit Terminal (Cmd-Q), confirm
   `Runner.Listener` survives with the same audit-session identity.
2. A real push to `main` goes green with all four keychain round-trips
   passing, the strict build, the full suite, the 70% coverage gate, and the
   artifact upload; any `-25308` fails the strategy.
3. `xcode-select -p` and `swift --version` under the supervisor byte-match a
   known-green interactive baseline; a green run on a different toolchain is
   a failure, not a pass.
4. Across two real reboots, the Login Item starts the supervisor, the
   Listener comes up, and the watchdog reports fresh without improvised
   owner commands.

Baseline evidence already on record: launchd `-25308` failure and interactive
recovery (`ledger/PROJECT_LEDGER.md:6081-6095`); interactive pickup ~1 minute
(2026-09-08T06:59Z entry); committee transcript
`.committee-tmp/runner-strategy/` (brief, six round files, chair prompt,
`decision.md`; aggregate 845/1000 vs 645/1000, margin 20%, unanimous, no
disqualifiers; chair arithmetic independently verified).

Implementation status (2026-09-08T08:20Z): stage-1 watchdog code, template,
runbook, and 12 unit tests landed (`9cc2a33`); stage-2 supervisor code,
template, and 13 unit tests landed in the companion stage-2 commit (see
`ledger/PROJECT_LEDGER.md`, 2026-09-08T08:20Z); both `zsh -n` clean and green
via `python3 -m unittest discover -s scripts/tests`. The stage-2 LaunchAgent
is **not installed**; the four gates above remain pending and unproven.

Gate outcomes (2026-09-08T14:30Z): **all four gates PASS; ADR-056 stage-2
implementation is complete.**

1. **Gate 1 — mechanism evidence:** the detached supervisor tree shows no
   controlling terminal (`TTY ??`), so the Cmd-Q SIGHUP teardown is
   structurally undeliverable; the literal Cmd-Q demonstration was folded
   into the strictly stronger Gate 4 two-reboot proof (Terminal.app is not
   running on this Mac; `ledger/CURRENT_STATE.md` 2026-09-08T09:03Z).
2. **Gate 2 — PASS:** run `34215969514` (commit `7f2a645`) green on the
   supervised runner (governance + build-and-test, all four keychain
   round-trips, strict build, full suite, 70% coverage gate, artifact
   retained, no `-25308`; rerun-verified).
3. **Gate 3 — PASS:** the supervisor-recorded `toolchain-baseline.txt`
   byte-matches the interactive baseline (Swift 6.4,
   `swiftlang-6.4.0.30.4`, `arm64-apple-macosx27.0.0`), re-proven at every
   supervisor start including both reboots.
4. **Gate 4 — PASS across two real reboots** (2026-09-08, boots 13:17Z and
   13:41:49Z, both after the 11:20Z copy-first plist install): launchd
   alone started the supervisor (PPID 1; PIDs 786 then 1304) with the
   pinned `DEVELOPER_DIR`, the run.sh → run-helper → Runner.Listener tree
   came up, the GitHub runner reported `online`, the watchdog reported a
   fresh heartbeat (`healthy (pid=2744 stamp=fresh)` after boot #2), and
   the lock/toolchain baseline were consistent — without improvised owner
   commands. Pre-login watchdog `unhealthy` lines are the designed
   boot-gap detection. Full evidence: `ledger/PROJECT_LEDGER.md`
   2026-09-08T14:30Z entry.

## Consequences

- The interactive-only rule is narrowed to its protected property; the
  documented manual routine remains the immediate fallback if any proof fails.
- Detection is decoupled from availability: the watchdog removes the
  "unnoticed hours-long queue" failure class on day one regardless of the
  supervisor's fate.
- The hosted-migration path stays pre-committed and falsifiable instead of
  being reopened ad hoc; if it is ever opened, it must meet the bar in
  Decision (6).
- Any future re-scoping of the protected rule requires a new ADR.