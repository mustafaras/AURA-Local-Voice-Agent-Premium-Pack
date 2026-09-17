# ADR-066: Launch at Login by Default; Always-On Runtime

- Status: Accepted — PA-2 G2-5 (2026-09-17). Proposed at G2-1 (2026-09-16); accepted after
  the full suite (22/22 bundles ×3, 0 failed), the readiness gate (G2-3, `Boşta` in 4.69 s
  from a LaunchServices launch), and the owner's real logout → login (G2-4: AURA started by
  launchd 61 s after the console session opened, `Boşta`, zero dialogs, `sfltool dumpbtm`
  → `/Applications/AURA.app` enabled; owner-attested)
- Date: 2026-09-16
- Owners: Personal Assistant track (PA-2) / release owner (user)
- Supersedes: the launch-at-login sentence of ADR-055 §2 ("`lifecycle.launchAtLogin` keeps
  its `.confirm` requirement") — already lifted for the owner posture by ADR-064; this ADR
  changes the *default*, not the capability gate. Builds on ADR-045/046 (lifecycle), ADR-063
  (UI-5 onboarding stage machine, still behavior-frozen), ADR-064 (owner trust posture),
  ADR-065 (stable identity; a login-item launch is a LaunchServices launch of the same
  identity)
- Superseded by: —

## Context

The owner's instruction (2026-09-15, verbatim in `personal-assistant-plan/README.md`):
"bilgisayar açılışıyla birlikte uygulama çalışsın … her görev için asistan hazır olmalı". A
personal assistant that has to be found and started after every restart is not always on.

State before PA-2 (`personal-assistant-plan/03-launch-at-login-always-on.md` §1):

- The registration machinery exists and is production-wired:
  `Sources/AuraLifecycle/LaunchAtLoginService.swift` wraps `SMAppService.mainApp`;
  `LaunchAtLoginController` persists the preference (`lifecycle.launchAtLoginEnabled`),
  records health, and emits events.
- The default was **off**: `userPreferenceEnabled()` read the schema default `false`
  (`Sources/AuraConfig/ConfigurationTypes.swift:201-204`) as if the user had chosen it.
- The onboarding `launchAtLogin` stage was an optional opt-in, last in the flow.
- `LaunchAtLoginStatus` raw values did **not** match `SMAppService.Status`
  (`ServiceManagement/SMAppService.h`: notRegistered 0, enabled 1, requiresApproval 2,
  notFound 3). macOS's `notRegistered` decoded as `.unknown` (health "unsupported") and
  `requiresApproval` decoded as `.notFound`, so the one state that needs the owner's hand
  was invisible.
- `sfltool dumpbtm` on this machine listed the AURA login item at a stale build path
  (`~/Library/Developer/AURA/aura-ui4-g44/AURA.app`), i.e. the item pointed at a bundle the
  owner no longer runs (`personal-assistant-plan/evidence/PA-2/g2-1-deep-link-anchor.txt`).
- The capability gate: `lifecycle.launchAtLogin` is seeded `.none` under the owner posture
  (ADR-064, `DefaultPolicyGrants.ownerMutationConfirmation`), so a system-actor registration
  raises no confirmation card. The policy engine still evaluates and audits the user's
  Settings toggle through `Capability.lifecycleLaunchAtLogin`.

## Decision

1. **Default on, behind the posture value.** `LaunchAtLoginController` takes
   `defaultEnabled: Bool` at composition; `AuraKernel_Construction` passes
   `OwnerTrustPosture.isEnabled`. `userPreferenceEnabled()` answers `defaultEnabled` while
   no layer above `secureDefaults` carries the key (the schema's `false` is a placeholder,
   not a decision), and the user's explicit `userSettings` value wins over it. `AuraLifecycle`
   does not import `AuraPolicy`; the posture crosses the module boundary as a value.
   Flipping `OwnerTrustPosture.isEnabled` to `false` restores the opt-in default with no
   other change.

2. **Idempotent post-start registration of the running bundle.**
   `LaunchAtLoginController.ensureRegisteredAtLaunch()` runs from
   `AuraKernel_StartStop.registerLaunchAtLoginAfterStart()` on a detached task after the
   pipeline is up (the first render must not wait on the ServiceManagement XPC round trip,
   same reasoning as `probeExternalAvailability`). It registers only when the preference is
   on and macOS does not already list the item; a second launch records `changed: false`. It
   writes **no** preference layer — the default already supplies `true`, and a session
   override would outrank the user's later `false` for the rest of the session. It never
   throws: a ServiceManagement failure is a `.failed` health record, not a failed launch.
   Because `SMAppService.mainApp` registers the *running* bundle, the installed
   `/Applications/AURA.app` must be the one launched for the item to point there (G2-4
   verifies with `sfltool dumpbtm`).

3. **`.requiresApproval` is recorded, never worked around.** `LaunchAtLoginStatus` now
   mirrors `SMAppService.Status` raw values exactly and gains `.requiresApproval`
   (health `.requiresUserAction`). `ensureRegisteredAtLaunch()` does not call `register()`
   again in that state. The Settings Startup row shows the notice
   (`settings.launchAtLoginRequiresApproval`, EN/TR) and a button to the Login Items pane via
   `x-apple.systempreferences:com.apple.LoginItems-Settings.extension` — an anchor that was
   opened on this machine (macOS 27) and shown to land on the "Login Items" pane before it was
   shipped (`evidence/PA-2/g2-1-deep-link-anchor.txt`, screenshot). The owner's switch in
   System Settings is the only way out of that state, and the row says so.

4. **The off switch stays real.** The Settings toggle persists `false` in `userSettings` and
   unregisters; the post-start hook then does nothing on later launches. The user-actor path
   is still gated by `Capability.lifecycleLaunchAtLogin` (audited; `.none` confirmation under
   the owner posture, ADR-064).

5. **Onboarding `launchAtLogin` stage is informational** (G2-2). Copy changes from opt-in to
   statement — EN "AURA starts automatically when you log in. You can turn this off in
   Settings." / TR "AURA giriş yaptığınızda otomatik başlar. Ayarlar'dan kapatabilirsiniz." —
   with a live status row. The stage machine (ADR-063) is unchanged: stage order, optionality,
   and persistence are as before; only presentation and copy move.

6. **Readiness gate** (G2-3/G2-4). A LaunchServices launch (which is what an `SMAppService`
   login-item launch is; `scripts/sp011-acceptance/launch-aura.sh` uses `open -a` for the
   same TCC-attribution reason) must reach `Boşta` within 10 s with no onboarding sheet and
   no permission dialog — the PA-1 identity invariant is what makes the second half true.
   Emergency-stop state is in-memory only; a fresh login comes up armed and idle.

## Alternatives considered

- **Change the schema default to `true`.** Rejected: `AuraConfig` cannot see the posture
  without importing `AuraPolicy`, and a schema default would apply to every build, including
  a non-owner one, contradicting ADR-064's non-transferability.
- **Register from `reconcile()` via `setEnabled(true, actor: .system)`.** Rejected: that path
  persists a `sessionOverrides` value which outranks the user's `userSettings` `false` until
  the next launch, and it re-calls `register()` while macOS holds `.requiresApproval`.
- **Use a `LaunchAgent` plist instead of `SMAppService.mainApp`.** Rejected: a LaunchAgent
  would be a second TCC subject and a second identity to keep stable; the login item launches
  the same bundle through LaunchServices.
- **Hide the `.requiresApproval` state and keep retrying.** Rejected: honesty rule for states
  (`07-cross-cutting-constraints.md` §2) — macOS's decision is shown with the way to act on
  it.

## Security and privacy impact

- Widens: the owner build registers itself as a login item without a confirmation card.
  Owner-instructed, non-transferable (ADR-064 boundary). The policy engine still evaluates
  and audits the user-actor toggle; the system-actor launch hook is a lifecycle action of the
  same bundle identity and requests no new permission.
- Unchanged: TCC grants (a login-item launch is the same stable identity — ADR-065),
  privilege separation (ADR-034/044), ADR-049 local-only, emergency stop (ADR-019/039).
- No new data is stored; the preference key already existed.

## Operational impact

- First launch of the installed bundle after PA-2 registers `/Applications/AURA.app` and
  supersedes the stale build-path item (verified in G2-4 with `sfltool dumpbtm`).
- If macOS answers `.requiresApproval`, the Startup row shows the notice and the Login Items
  button; the owner flips the switch once. That state is recorded as `owner-attested`.
- Turning the item off is one toggle in Settings › Startup; it persists and unregisters.

## Migration

No schema change. Users who had set the key explicitly keep their value; the default only
applies where no user layer carries the key. `LaunchAtLoginStatus` raw values change; the
value was never persisted for logic (events carry the raw value for the audit trail only).

## Validation evidence

Gate by gate in `personal-assistant-plan/ledger/PHASE_LEDGER.md` (G2-1 … G2-6) and
`personal-assistant-plan/evidence/PA-2/`: controller stub tests for default-on, idempotent
registration, `.requiresApproval` mapping, failure recording (`unit`); Settings row / stage
view tests with EN/TR copy and identifiers (`integration`); deep-link anchor opened on this
machine (`os-observed`); LaunchServices launch → `Boşta` ≤ 10 s (`live-local`); real
logout → login with `pgrep`, driver `status`, `sfltool dumpbtm`, and the toggle off/on
(`os-observed` + `live-local` + `owner-attested`).

## Consequences

- Positive: the assistant is running after every login without being found or started;
  the approval state, if macOS applies it, is visible with a one-click path to fix it; the
  off switch is honest.
- Negative: a non-owner build must flip `OwnerTrustPosture.isEnabled` to get the opt-in
  default back (by design, ADR-064); a bundle launched from a build path registers that
  path, so acceptance runs must launch the installed bundle.
- Falsifiers: any launch that shows a confirmation card or a permission dialog for the
  login item; `sfltool dumpbtm` still listing a non-`/Applications` path after G2-4;
  `ensureRegisteredAtLaunch()` reporting `changed: true` on a second consecutive launch; the
  Settings toggle off leaving the item listed.
