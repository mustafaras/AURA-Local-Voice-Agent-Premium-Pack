# EV-SP-030-20260831-R11-POLICY-BLOCK-01

**Evidence ID:** EV-SP-030-20260831-R11-POLICY-BLOCK-01
**Track:** SP-030 / R11 — lifecycle capability reachability
**Type:** Defect finding — root cause, live-reproduced. **No fix applied; awaiting owner decision.**
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty)
**Session:** AURA-SP-030-SLO-INSTRUMENTATION-20260831

## Summary

R11's user-facing recovery and lifecycle controls — launch at login, safe mode,
reset, rollback, uninstall, factory reset, update check/stage/approve — are
**unreachable from the running application**. Every one of them is denied by the
policy engine before it reaches its implementation.

This is not a missing feature or a missing test. The implementations exist, are
tested, and are wired into the composition root. They are unreachable because
the authorization path that the source code names as their access route does not
grant them, and the fallback that would have granted them is closed at a second
point.

**It was invisible until 2026-08-30**, when a launch-at-login toggle was added
to Settings. Before that, no UI called these methods, so nothing exercised the
gate. The toggle did not create this defect — it revealed it.

## How it was found

Live, on the running signed application (`/Applications/AURA.app`, 2026-08-31
build), not by reading source. Settings → *Girişte AURA'yı başlat* was clicked:

```
Girişte AURA'yı başlat  →  0 → 0     (state did not change)
detail: "Permission denied: No matching grant and tier mutation is
         denied by default"
```

The toggle reports the failure rather than silently reverting, which is correct
behaviour on `setLaunchAtLogin`'s error path — the observable symptom is an
honest one. `SMAppService` is **not** the blocker and was never reached.

## Root cause — two layers, only the first currently firing

### Layer 1 — denied for want of a grant (active)

`Capability.lifecycleLaunchAtLogin` is `riskTier: .mutation`
(`Sources/AuraCore/PolicyTypes_Capability.swift:232`). The default
`PolicyConfiguration` (`PolicyTypes_PolicyConfiguration.swift:30-31`) is:

```swift
allowByDefaultTiers: []
denyByDefaultTiers:  [.reversible, .mutation, .destructive, .network]
```

— everything except `.observation`. With no matching grant, evaluation reaches
`PolicyEngine_Evaluation.swift:44-48` and denies. No grant exists: the
capability registry lists it, and the whole lifecycle family, as
`.disabled(reason: lifecycleDirectCallReason)`
(`InitialCapabilitySet_CapabilityDefinitions.swift:94-105`).

### The false assertion at the centre of this

That `disabled` reason states, in the source:

> *"Wired into the composition root and reachable through direct `AuraKernel`
> RuntimeAPI calls; not routed through the natural-language intent engine in
> this pass."*

The first half is the compensating control for the second. Keeping these
capabilities out of the NLU classifier is a deliberate and defensible design
decision — the accompanying comment gives the reason, that they "require
explicit user-controlled settings or high-stakes confirmation flows". **But the
direct-call route it names as the alternative does not work.** The comment
documents a reachability guarantee the code does not provide, and that is the
actual defect: not the disable, but the unverified escape hatch.

### Layer 2 — the direct-call path fails closed on confirmation (latent)

`AuraKernel_RuntimeAPI.evaluateDirectCapability` handles `.confirm` by throwing
(`AuraKernel_RuntimeAPI.swift:304-310`):

```swift
case .confirm:
  // No confirmation presenter is wired for this direct-call path yet;
  // fail closed rather than silently proceed or silently auto-confirm.
  throw AuraError.permissionDenied(...)
```

Failing closed is the right default and this comment is accurate. But a
presenter **does** exist: `AuraKernel.confirmationPresenter`
(`AuraKernel.swift:33`), constructed in `AuraAppModel` (`AuraAppModel.swift:104`),
handler installed at `AuraAppModel_Settings.swift:152`, and already passed as
`approvalPresenter` to four other subsystems in `AuraKernel_Construction.swift`.
It is wired everywhere except here.

This layer is **latent, not active**: today the request is denied at layer 1
before it can reach `.confirm`. It matters because it blocks the obvious repair
— it fires precisely when someone adds a grant that requires confirmation.

## Blast radius — verified, not assumed

Eighteen `evaluateDirectCapability` call sites in `AuraKernel_RuntimeAPI.swift`
cover eleven lifecycle capabilities. Tiers read from
`PolicyTypes_Capability.swift`:

| Capability | Tier | Reachable today |
|---|---|---|
| `lifecycleLaunchAtLogin` | `.mutation` | **DENIED** |
| `lifecycleSafeMode` | `.mutation` | **DENIED** |
| `lifecycleReset` | `.destructive` | **DENIED** |
| `lifecycleRollback` | `.destructive` | **DENIED** |
| `lifecycleUninstall` | `.destructive` | **DENIED** |
| `lifecycleFactoryReset` | `.destructive` | **DENIED** |
| `lifecycleApproveUpdate` | `.destructive` | **DENIED** |
| `lifecycleStageUpdate` | `.destructive` | **DENIED** |
| `lifecycleCheckUpdate` | `.network` | **DENIED** |
| `lifecycleSupportBundle` | `.observation` | allowed |
| `lifecycleMigrationPreflight` | `.observation` | allowed |

Nine of eleven are denied. The two that work are `.observation` tier, which is
absent from `denyByDefaultTiers`; they then clear `defaultConfirmationRequired`
because `observation (0) >= mutation (2)` is false. So the surface is not
uniformly broken, and the two exceptions are exactly the two read-only ones —
which is itself the confirmation that tier, not wiring, is what decides this.

## Consequence for the record

The risk register's `RISK-NO-LAUNCH-AT-LOGIN` row says *"Live ServiceManagement
mutation remains blocked by authority."* That is **incomplete, and in a way that
matters**: it implies granting authority would suffice. It would not. Even with
full authority and the owner present, the toggle fails — the block is in the
policy wiring, ahead of anything `SMAppService` does. The row is amended in this
pass to say so.

This also means **no SP-028 lifecycle capability has ever been exercised through
the product**, only through tests that call the controllers directly. The
distinction between "implemented and tested" and "reachable by a user" was not
being checked anywhere.

## Decision required — this changes the authorization path, so it is the owner's

Not taken by this session. `SECOND_PASS_STATE.json.authority` records
`mutate_permissions: false`, and defining a policy grant is a permission
mutation by any reading.

- **Option A — define a grant for `lifecycleLaunchAtLogin` and wire
  `evaluateDirectCapability` to the existing `confirmationPresenter`.** Matches
  the product design the code already describes ("high-stakes confirmation
  flows") and closes both layers. A narrower variant, a grant with
  `confirmationRequirement: .none`, would work without touching layer 2 — it is
  a smaller change but authorizes a mutation-tier action with no prompt, which
  is a weaker posture than the design asks for.
- **Option B — record the finding only, change nothing.** R11's live gates stay
  unreachable and stay blocked.

Until this is decided, the live R11 gates cannot be run and R11 cannot close.

## Verification

| Check | Result |
|---|---|
| Live toggle in the signed app | Denied, message quoted above; state unchanged |
| `./scripts/aura-test.sh /tmp/aurabuild` | 1317 tests / 86 suites / 22 bundles, 0 failures |

The full suite passes **with this defect present**, which is the point worth
recording: 1317 tests do not include one that asserts a lifecycle capability is
reachable by a user. Any fix under Option A should add that test, not just the
grant.

## What this does NOT change

No fix applied. No grant defined. No policy configuration altered. No SLO
measured, no scenario re-run, no sign-off obtained, no gate moved. R11 stays
`in_progress`; SP-030 stays `blocked`; SP-031 must not start.

## Falsifiers

Any of the following would falsify this record: that the launch-at-login toggle
succeeds from the UI on an unmodified tree; that `SMAppService` or TCC is the
blocker; that a grant for `lifecycleLaunchAtLogin` exists; that
`evaluateDirectCapability` presents a confirmation; that the `.observation`-tier
lifecycle capabilities are also denied; or that any lifecycle capability has
been exercised end-to-end through the product UI rather than through a direct
test call.
