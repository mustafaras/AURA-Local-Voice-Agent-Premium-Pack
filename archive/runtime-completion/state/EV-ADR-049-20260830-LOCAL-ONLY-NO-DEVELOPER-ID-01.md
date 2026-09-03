# EV-ADR-049-20260830-LOCAL-ONLY-NO-DEVELOPER-ID-01

**Evidence ID:** EV-ADR-049-20260830-LOCAL-ONLY-NO-DEVELOPER-ID-01
**Track:** R0/R11/R12 release scope
**Type:** Decision/authority — Adopted ADR-049 (permanent local-only, no Developer ID)
**Commit:** `6ef97e8` (`main == origin/main`) prior to this update
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, Python 3.14.6, Git 2.54.0
**Session:** AURA-SP-029-BETA-CONTRACT-20260829

## Decision

The release owner (user) explicitly decided that AURA is a **permanent
local-only product** and will **never acquire or use a Developer ID certificate
or Apple notarization** (user instruction: "developer id almayacağız ve
kullanmayacağız"). This is recorded as **ADR-049** and supersedes any earlier
active wording that presented Developer ID/notarization as a required or
re-openable release prerequisite.

## What changed (normative/active documents only; append-only history untouched)

- Created `docs/decisions/ADR-049-local-only-no-developer-id.md` (Accepted).
- `TOOLCHAIN.md`, `session toolchain-manifest.json`, `ADR-045` release line:
  local-only release baseline = local nested sign + hardened runtime + artifact
  hashes + launch evidence; Developer ID/notarization/external clean-machine
  permanently out of scope.
- `docs/operations/RELEASE_ARTIFACTS.md`, `33_DEPLOYMENT.md`,
  `UPDATE_MECHANISM.md`, `ADR-046`, `ADR-023`: updated the relevant release
  wording to the local-only boundary.
- `README.md`, `SESSION_STARTER.md`, `R11_CLOSURE_PLAN.md`: Developer ID is not
  a requirement and will not be re-opened.
- `SECOND_PASS_OPEN_GAPS.md` R11 row + `current-state.json`
  `GATE-DEVELOPER-ID-NOTARIZATION` (now **waived**) and authority source:
  permanent out-of-scope per ADR-049.
- `RISK_REGISTER.md` `RISK-NOT-NOTARIZED`: Accepted (permanent local-only
  scope, ADR-049).
- `DECISION_REGISTER.md`: ADR-049 Accepted.

## Honest non-claims

- No Developer ID certificate, notarization, stapling, or external/public
  distribution was performed or is claimed (and none is possible without Apple
  credentials, which are not sought).
- The signed bundle is local-identity + hardened-runtime only and is **not**
  presented as external distribution.
- `beta-readiness.json` remains `blocked`; the artifact stays
  `development_unverified`.

## Falsifiers

- Any claim that Developer ID signing, notarization, stapling, external
  distribution, or external clean-machine release evidence occurred would
  falsify ADR-049.
- Any claim that ADR-049 is a temporary/waivable exception rather than a
  permanent owner-instructed scope decision would be false.

## Next action

Proceed with the local-only R11/R12 path under ADR-049: close the locally
closable R11 gates, formalize ADR-046 (local-only), keep `beta-readiness.json`
blocked until SP-030/SP-031 evidence closes the R12 direct-evidence gates, and
record all validators passing.
